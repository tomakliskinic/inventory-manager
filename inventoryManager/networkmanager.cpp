#include "networkmanager.h"

#include <QDataStream>
#include <QDateTime>
#include <QDebug>
#include <QHostAddress>
#include <QHostInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QNetworkInterface>
#include <QSettings>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QUdpSocket>
#include <QUuid>

NetworkManager::NetworkManager(QObject *parent)
    : QObject(parent)
{
    QSettings s;
    m_deviceName = s.value("network/deviceName", defaultDeviceName()).toString();
    m_instanceUuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
}

NetworkManager::~NetworkManager()
{
    stopDiscovery();
}

QString NetworkManager::deviceName() const
{
    return m_deviceName;
}

void NetworkManager::setDeviceName(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || trimmed == m_deviceName)
        return;
    m_deviceName = trimmed;
    QSettings().setValue("network/deviceName", m_deviceName);
    emit deviceNameChanged();
}

QVariantList NetworkManager::peers() const
{
    return m_peers;
}

bool NetworkManager::discoveryRunning() const
{
    return m_discoveryRunning;
}

void NetworkManager::startDiscovery()
{
    if (m_discoveryRunning)
        return;

    m_socket = new QUdpSocket(this);
    if (!m_socket->bind(QHostAddress::AnyIPv4, DiscoveryPort,
                        QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint)) {
        qWarning() << "NetworkManager: UDP bind failed:" << m_socket->errorString();
        m_socket->deleteLater();
        m_socket = nullptr;
        return;
    }
    connect(m_socket, &QUdpSocket::readyRead, this, &NetworkManager::onReadyRead);

    m_tcpServer = new QTcpServer(this);
    if (!m_tcpServer->listen(QHostAddress::Any, 0)) {
        qWarning() << "NetworkManager: TCP listen failed:" << m_tcpServer->errorString();
        m_socket->close();
        m_socket->deleteLater();
        m_socket = nullptr;
        m_tcpServer->deleteLater();
        m_tcpServer = nullptr;
        return;
    }
    m_tcpPort = m_tcpServer->serverPort();
    connect(m_tcpServer, &QTcpServer::newConnection, this, &NetworkManager::onNewTcpConnection);

    m_broadcastTimer = new QTimer(this);
    connect(m_broadcastTimer, &QTimer::timeout, this, &NetworkManager::broadcastPresence);
    m_broadcastTimer->start(BroadcastIntervalMs);

    m_pruneTimer = new QTimer(this);
    connect(m_pruneTimer, &QTimer::timeout, this, &NetworkManager::pruneStalePeers);
    m_pruneTimer->start(PruneIntervalMs);

    broadcastPresence();

    m_discoveryRunning = true;
    emit discoveryRunningChanged();
    qDebug() << "NetworkManager: discovery started as" << m_deviceName
             << "uuid" << m_instanceUuid << "tcp" << m_tcpPort;
}

void NetworkManager::stopDiscovery()
{
    if (!m_discoveryRunning)
        return;

    if (m_broadcastTimer) {
        m_broadcastTimer->stop();
        m_broadcastTimer->deleteLater();
        m_broadcastTimer = nullptr;
    }
    if (m_pruneTimer) {
        m_pruneTimer->stop();
        m_pruneTimer->deleteLater();
        m_pruneTimer = nullptr;
    }
    if (m_socket) {
        m_socket->close();
        m_socket->deleteLater();
        m_socket = nullptr;
    }
    if (m_tcpServer) {
        m_tcpServer->close();
        m_tcpServer->deleteLater();
        m_tcpServer = nullptr;
    }
    for (QTcpSocket *sock : m_inboundBuffers.keys())
        sock->deleteLater();
    m_inboundBuffers.clear();
    m_tcpPort = 0;

    m_peerMap.clear();
    rebuildPeersList();

    m_discoveryRunning = false;
    emit discoveryRunningChanged();
    qDebug() << "NetworkManager: discovery stopped";
}

void NetworkManager::broadcastPresence()
{
    if (!m_socket)
        return;
    const QJsonObject obj{
        {"app", "inventoryManager"},
        {"v", 1},
        {"uuid", m_instanceUuid},
        {"name", m_deviceName},
        {"tcp", m_tcpPort}
    };
    const QByteArray bytes = QJsonDocument(obj).toJson(QJsonDocument::Compact);

    m_socket->writeDatagram(bytes, QHostAddress::Broadcast, DiscoveryPort);

    const auto interfaces = QNetworkInterface::allInterfaces();
    for (const QNetworkInterface &iface : interfaces) {
        const auto flags = iface.flags();
        if (!(flags & QNetworkInterface::IsUp)) continue;
        if (!(flags & QNetworkInterface::IsRunning)) continue;
        if (flags & QNetworkInterface::IsLoopBack) continue;

        const auto entries = iface.addressEntries();
        for (const QNetworkAddressEntry &entry : entries) {
            if (entry.ip().protocol() != QAbstractSocket::IPv4Protocol)
                continue;
            const QHostAddress bcast = entry.broadcast();
            if (bcast.isNull())
                continue;
            m_socket->writeDatagram(bytes, bcast, DiscoveryPort);
        }
    }
}

void NetworkManager::onReadyRead()
{
    while (m_socket && m_socket->hasPendingDatagrams()) {
        QByteArray buf;
        buf.resize(int(m_socket->pendingDatagramSize()));
        QHostAddress sender;
        quint16 senderPort = 0;
        m_socket->readDatagram(buf.data(), buf.size(), &sender, &senderPort);

        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(buf, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject())
            continue;
        const QJsonObject obj = doc.object();
        if (obj.value("app").toString() != QLatin1String("inventoryManager"))
            continue;
        const QString uuid = obj.value("uuid").toString();
        if (uuid.isEmpty() || uuid == m_instanceUuid)
            continue;

        bool isNew = !m_peerMap.contains(uuid);
        PeerEntry &p = m_peerMap[uuid];
        p.uuid = uuid;
        p.name = obj.value("name").toString();
        p.tcpPort = quint16(obj.value("tcp").toInt());
        bool v4Ok = false;
        const quint32 v4 = sender.toIPv4Address(&v4Ok);
        p.address = v4Ok ? QHostAddress(v4).toString() : sender.toString();
        p.lastSeenMs = QDateTime::currentMSecsSinceEpoch();

        if (isNew) {
            qDebug() << "NetworkManager: peer discovered" << p.name
                     << "at" << p.address << ":" << p.tcpPort << "uuid" << p.uuid;
        }
        rebuildPeersList();
    }
}

void NetworkManager::pruneStalePeers()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    bool changed = false;
    auto it = m_peerMap.begin();
    while (it != m_peerMap.end()) {
        if (now - it.value().lastSeenMs > PeerTtlMs) {
            qDebug() << "NetworkManager: peer expired" << it.value().name
                     << "at" << it.value().address;
            it = m_peerMap.erase(it);
            changed = true;
        } else {
            ++it;
        }
    }
    if (changed)
        rebuildPeersList();
}

void NetworkManager::rebuildPeersList()
{
    QVariantList list;
    list.reserve(m_peerMap.size());
    for (const PeerEntry &p : std::as_const(m_peerMap)) {
        QVariantMap m;
        m["uuid"] = p.uuid;
        m["name"] = p.name;
        m["address"] = p.address;
        m["tcpPort"] = p.tcpPort;
        list.append(m);
    }
    m_peers = list;
    emit peersChanged();
}

void NetworkManager::sendPackJson(const QString &peerUuid, const QString &packJson)
{
    if (!m_peerMap.contains(peerUuid)) {
        emit shareFailed(peerUuid, tr("Peer no longer available"));
        return;
    }
    const PeerEntry p = m_peerMap[peerUuid];
    if (p.tcpPort == 0) {
        emit shareFailed(peerUuid, tr("Peer did not advertise a TCP port"));
        return;
    }
    if (packJson.isEmpty()) {
        emit shareFailed(peerUuid, tr("Pack is empty"));
        return;
    }

    QJsonParseError err;
    const QJsonDocument inner = QJsonDocument::fromJson(packJson.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !inner.isObject()) {
        emit shareFailed(peerUuid, tr("Pack is not valid JSON: %1").arg(err.errorString()));
        return;
    }
    const QJsonObject envelope{
        {"kind", "homebrew_pack_share"},
        {"v", 1},
        {"sender", m_deviceName},
        {"pack", inner.object()}
    };
    const QByteArray payload = QJsonDocument(envelope).toJson(QJsonDocument::Compact);

    QTcpSocket *sock = new QTcpSocket(this);
    const QString peerName = p.name;

    connect(sock, &QTcpSocket::connected, this, [this, sock, payload, peerUuid, peerName]() {
        sock->write(packMessage(payload));
        sock->disconnectFromHost();
        emit shareSent(peerUuid, peerName);
    });
    connect(sock, &QTcpSocket::errorOccurred, this, [this, sock, peerUuid](QAbstractSocket::SocketError) {
        emit shareFailed(peerUuid, sock->errorString());
        sock->deleteLater();
    });
    connect(sock, &QTcpSocket::disconnected, sock, &QObject::deleteLater);

    qDebug() << "NetworkManager: sending" << payload.size() << "bytes to"
             << peerName << "at" << p.address << ":" << p.tcpPort;
    sock->connectToHost(p.address, p.tcpPort);
}

void NetworkManager::sendInventoryItem(const QString &peerUuid,
                                       const QString &payloadJson,
                                       int sourceItemId,
                                       int sharedQuantity,
                                       const QString &itemLabel)
{
    if (m_outboundSocket) {
        emit itemTransferFailed(peerUuid, itemLabel, tr("Another transfer is already in progress"));
        return;
    }
    if (!m_peerMap.contains(peerUuid)) {
        emit itemTransferFailed(peerUuid, itemLabel, tr("Peer no longer available"));
        return;
    }
    const PeerEntry p = m_peerMap[peerUuid];
    if (p.tcpPort == 0) {
        emit itemTransferFailed(peerUuid, itemLabel, tr("Peer did not advertise a TCP port"));
        return;
    }
    if (payloadJson.isEmpty()) {
        emit itemTransferFailed(peerUuid, itemLabel, tr("Item payload is empty"));
        return;
    }

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(payloadJson.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        emit itemTransferFailed(peerUuid, itemLabel, tr("Item payload is not valid JSON: %1").arg(err.errorString()));
        return;
    }
    QJsonObject env = doc.object();
    env["sender"] = m_deviceName;
    const QByteArray finalBytes = QJsonDocument(env).toJson(QJsonDocument::Compact);

    QTcpSocket *sock = new QTcpSocket(this);
    m_outboundSocket = sock;
    m_outboundPeerUuid = peerUuid;
    m_outboundPeerName = p.name;
    m_outboundItemLabel = itemLabel;
    m_outboundSourceItemId = sourceItemId;
    m_outboundSharedQty = sharedQuantity;
    m_outboundResponseBuffer.clear();

    connect(sock, &QTcpSocket::connected, this, [this, sock, finalBytes]() {
        sock->write(packMessage(finalBytes));
    });
    connect(sock, &QTcpSocket::readyRead, this, [this, sock]() {
        m_outboundResponseBuffer.append(sock->readAll());
        QByteArray resp;
        if (tryExtractMessage(m_outboundResponseBuffer, resp)) {
            const QJsonDocument respDoc = QJsonDocument::fromJson(resp);
            const QString status = respDoc.isObject()
                ? respDoc.object().value("status").toString()
                : QString();
            if (status == QLatin1String("accepted")) {
                emit itemTransferAccepted(m_outboundPeerUuid, m_outboundPeerName,
                                          m_outboundSourceItemId, m_outboundSharedQty,
                                          m_outboundItemLabel);
            } else {
                emit itemTransferDeclined(m_outboundPeerUuid, m_outboundPeerName,
                                          m_outboundItemLabel);
            }
            sock->disconnectFromHost();
        }
    });
    connect(sock, &QTcpSocket::errorOccurred, this, [this, sock](QAbstractSocket::SocketError) {
        const QString uuid = m_outboundPeerUuid;
        const QString label = m_outboundItemLabel;
        const QString errStr = sock->errorString();
        emit itemTransferFailed(uuid, label, errStr);
        if (m_outboundSocket == sock)
            resetOutboundState();
        sock->deleteLater();
    });
    connect(sock, &QTcpSocket::disconnected, this, [this, sock]() {
        if (m_outboundSocket == sock)
            resetOutboundState();
        sock->deleteLater();
    });

    m_outboundTimeout = new QTimer(this);
    m_outboundTimeout->setSingleShot(true);
    m_outboundTimeout->setInterval(OutboundTimeoutMs);
    connect(m_outboundTimeout, &QTimer::timeout, this, [this]() {
        if (!m_outboundSocket) return;
        qDebug() << "NetworkManager: outbound transfer timed out";
        const QString uuid = m_outboundPeerUuid;
        const QString label = m_outboundItemLabel;
        QTcpSocket *sock = m_outboundSocket;
        emit itemTransferFailed(uuid, label, tr("Transfer timed out"));
        sock->disconnectFromHost();
        resetOutboundState();
        sock->deleteLater();
    });
    m_outboundTimeout->start();

    qDebug() << "NetworkManager: sending inventory item to" << p.name
             << "at" << p.address << ":" << p.tcpPort
             << "(" << finalBytes.size() << "bytes)";
    sock->connectToHost(p.address, p.tcpPort);
}

void NetworkManager::cancelOutboundTransfer()
{
    if (!m_outboundSocket) return;
    qDebug() << "NetworkManager: outbound transfer canceled by user";
    m_outboundSocket->disconnectFromHost();
}

void NetworkManager::respondToItemTransfer(bool accepted)
{
    if (!m_inboundResponseSocket)
        return;
    const QJsonObject obj{{"status", accepted ? "accepted" : "declined"}};
    const QByteArray resp = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    m_inboundResponseSocket->write(packMessage(resp));
    m_inboundResponseSocket->disconnectFromHost();
    m_inboundResponseSocket = nullptr;
}

void NetworkManager::resetOutboundState()
{
    m_outboundSocket = nullptr;
    m_outboundPeerUuid.clear();
    m_outboundPeerName.clear();
    m_outboundItemLabel.clear();
    m_outboundSourceItemId = -1;
    m_outboundSharedQty = 0;
    m_outboundResponseBuffer.clear();
    if (m_outboundTimeout) {
        m_outboundTimeout->stop();
        m_outboundTimeout->deleteLater();
        m_outboundTimeout = nullptr;
    }
}

void NetworkManager::onNewTcpConnection()
{
    if (!m_tcpServer)
        return;
    while (QTcpSocket *sock = m_tcpServer->nextPendingConnection()) {
        m_inboundBuffers.insert(sock, QByteArray());
        const QString peer = sock->peerAddress().toString();
        qDebug() << "NetworkManager: inbound TCP from" << peer;

        connect(sock, &QTcpSocket::readyRead, this, [this, sock]() {
            m_inboundBuffers[sock].append(sock->readAll());
            QByteArray payload;
            while (tryExtractMessage(m_inboundBuffers[sock], payload))
                handleIncomingMessage(sock, payload);
        });
        connect(sock, &QTcpSocket::disconnected, this, [this, sock]() {
            m_inboundBuffers.remove(sock);
            if (m_inboundResponseSocket == sock) {
                m_inboundResponseSocket = nullptr;
                qDebug() << "NetworkManager: inbound socket lost before user responded";
                emit incomingTransferCanceled();
            }
            sock->deleteLater();
        });
    }
}

void NetworkManager::handleIncomingMessage(QTcpSocket *sock, const QByteArray &payload)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(payload, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "NetworkManager: incoming message is not valid JSON:" << err.errorString();
        return;
    }
    const QJsonObject env = doc.object();
    const QString kind = env.value("kind").toString();

    if (kind == QLatin1String("homebrew_pack_share")) {
        if (!env.value("pack").isObject()) {
            qWarning() << "NetworkManager: incoming share missing pack object";
            return;
        }
        const QJsonObject pack = env.value("pack").toObject();
        const QJsonArray items = pack.value("items").toArray();
        const QString sender = env.value("sender").toString();
        const QString packJson = QString::fromUtf8(QJsonDocument(pack).toJson(QJsonDocument::Compact));
        qDebug() << "NetworkManager: pack received from" << sender
                 << "with" << items.size() << "item(s)";
        emit shareReceived(sender, items.size(), packJson);
        sock->disconnectFromHost();
    } else if (kind == QLatin1String("inventory_item_share")) {
        if (m_inboundResponseSocket) {
            qWarning() << "NetworkManager: already a pending item transfer, auto-declining";
            const QJsonObject decline{{"status", "declined"}, {"reason", "busy"}};
            sock->write(packMessage(QJsonDocument(decline).toJson(QJsonDocument::Compact)));
            sock->disconnectFromHost();
            return;
        }
        const QJsonObject root = env.value("root").toObject();
        const QJsonObject def = root.value("definition").toObject();
        const QString sender = env.value("sender").toString();
        const QString itemName = def.value("name").toString();
        qDebug() << "NetworkManager: item transfer from" << sender << "for" << itemName;
        m_inboundResponseSocket = sock;
        emit itemTransferReceived(sender, itemName, QString::fromUtf8(payload));
    } else {
        qWarning() << "NetworkManager: unknown kind:" << kind;
        sock->disconnectFromHost();
    }
}

QByteArray NetworkManager::packMessage(const QByteArray &payload)
{
    QByteArray out;
    out.reserve(4 + payload.size());
    QDataStream ds(&out, QIODevice::WriteOnly);
    ds.setByteOrder(QDataStream::BigEndian);
    ds << static_cast<quint32>(payload.size());
    out.append(payload);
    return out;
}

bool NetworkManager::tryExtractMessage(QByteArray &buf, QByteArray &out)
{
    if (buf.size() < 4)
        return false;
    quint32 len = 0;
    {
        QDataStream ds(buf.left(4));
        ds.setByteOrder(QDataStream::BigEndian);
        ds >> len;
    }
    if (len > 16u * 1024u * 1024u) {
        qWarning() << "NetworkManager: message length suspicious:" << len << "; resetting buffer";
        buf.clear();
        return false;
    }
    if (buf.size() < qsizetype(4 + len))
        return false;
    out = buf.mid(4, qsizetype(len));
    buf.remove(0, qsizetype(4 + len));
    return true;
}

QString NetworkManager::defaultDeviceName() const
{
    const QString host = QHostInfo::localHostName();
    return host.isEmpty() ? QStringLiteral("Unnamed device") : host;
}
