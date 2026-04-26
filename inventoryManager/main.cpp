#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QDebug>

#include "databasemanager.h"
#include "enums.h"

int main(int argc, char *argv[])
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
#endif

    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Material");

    DatabaseManager db;
    QString dbPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/inventory.sqlite";

    if (!db.initialize(dbPath)) {
        qFatal("Database initialization failed");
        return -1;
    }

    qmlRegisterSingletonInstance("inventoryManager", 1, 0, "DB", &db);
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
