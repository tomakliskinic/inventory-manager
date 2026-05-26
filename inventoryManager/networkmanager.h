#ifndef NETWORKMANAGER_H
#define NETWORKMANAGER_H

#include <QObject>
#include <QString>
#include <QHash>
#include <QByteArray>
#include <QVariantList>

class QUdpSocket;
class QTcpServer;
class QTcpSocket;
class QTimer;

class NetworkManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString deviceName READ deviceName WRITE setDeviceName NOTIFY deviceNameChanged)
    Q_PROPERTY(QVariantList peers READ peers NOTIFY peersChanged)
    Q_PROPERTY(bool discoveryRunning READ discoveryRunning NOTIFY discoveryRunningChanged)

public:
    explicit NetworkManager(QObject *parent = nullptr);
    ~NetworkManager();

    QString deviceName() const;
    void setDeviceName(const QString &name);

    QVariantList peers() const;
    bool discoveryRunning() const;

    Q_INVOKABLE void startDiscovery();
    Q_INVOKABLE void stopDiscovery();
    Q_INVOKABLE void sendPackJson(const QString &peerUuid, const QString &packJson);

signals:
    void deviceNameChanged();
    void peersChanged();
    void discoveryRunningChanged();
    void shareSent(const QString &peerUuid, const QString &peerName);
    void shareFailed(const QString &peerUuid, const QString &reason);
    void shareReceived(const QString &senderName, int itemCount, const QString &packJson);

private slots:
    void onReadyRead();
    void broadcastPresence();
    void pruneStalePeers();
    void onNewTcpConnection();

private:
    struct PeerEntry {
        QString uuid;
        QString name;
        QString address;
        quint16 tcpPort = 0;
        qint64 lastSeenMs = 0;
    };

    QString defaultDeviceName() const;
    void rebuildPeersList();
    void handleIncomingShare(const QByteArray &data);

    static constexpr quint16 DiscoveryPort = 45454;
    static constexpr int BroadcastIntervalMs = 3000;
    static constexpr int PruneIntervalMs = 2000;
    static constexpr qint64 PeerTtlMs = 10000;

    QString m_deviceName;
    QString m_instanceUuid;
    QVariantList m_peers;
    QHash<QString, PeerEntry> m_peerMap;
    bool m_discoveryRunning = false;

    QUdpSocket *m_socket = nullptr;
    QTcpServer *m_tcpServer = nullptr;
    QHash<QTcpSocket *, QByteArray> m_inboundBuffers;
    quint16 m_tcpPort = 0;
    QTimer *m_broadcastTimer = nullptr;
    QTimer *m_pruneTimer = nullptr;
};

#endif // NETWORKMANAGER_H
