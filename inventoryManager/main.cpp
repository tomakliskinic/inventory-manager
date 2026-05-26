#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QDebug>

#include "databasemanager.h"
#include "networkmanager.h"
#include "enums.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName("inventoryManager");
    QGuiApplication::setApplicationName("inventoryManager");
    QQuickStyle::setStyle("Material");

    DatabaseManager db;
    QString dbPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/inventory.sqlite";

    if (!db.initialize(dbPath)) {
        qFatal("Database initialization failed");
        return -1;
    }

    NetworkManager net;
    net.startDiscovery();

    qmlRegisterSingletonInstance("inventoryManager", 1, 0, "DB", &db);
    qmlRegisterSingletonInstance("inventoryManager", 1, 0, "Net", &net);
    qmlRegisterUncreatableMetaObject(Enums::staticMetaObject, "inventoryManager", 1, 0, "Enums", "Enums is a namespace");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("inventoryManager", "Main");

    return QCoreApplication::exec();
}
