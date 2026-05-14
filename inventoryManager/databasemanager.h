#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QtSql/QSqlDatabase>
#include <QFileInfo>
#include <QDir>
#include <QUrl>

#include "enums.h"

class QJsonObject;

class DatabaseManager : public QObject
{
    Q_OBJECT
public:
    explicit DatabaseManager(QObject *parent = nullptr);
    ~DatabaseManager();

    bool initialize(const QString &dbPath);
    bool isInitialized() const;

    Q_INVOKABLE QString lastError() const;

    Q_INVOKABLE bool exportAllToFile(const QUrl &fileUrl);
    Q_INVOKABLE bool exportCharacterToFile(int characterId, const QUrl &fileUrl);
    Q_INVOKABLE int importFromFile(const QUrl &fileUrl);

    Q_INVOKABLE QStringList creatureSizeNames() const;

    Q_INVOKABLE int createCharacter(const QVariantMap &data);
    Q_INVOKABLE bool updateCharacter(int id, const QVariantMap &data);
    Q_INVOKABLE bool deleteCharacter(int id);
    Q_INVOKABLE QVariantMap getCharacter(int id);
    Q_INVOKABLE QVariantList getAllCharacters();

    Q_INVOKABLE QVariantMap getCoins(int characterId);
    Q_INVOKABLE bool updateCoins(int characterId, const QVariantMap &coins);

    Q_INVOKABLE QVariantList getItemDefinitions (int itemType = -1);
    Q_INVOKABLE QVariantMap getItemDefinition(int id);
    Q_INVOKABLE int createItemDefinition(const QVariantMap &data);
    Q_INVOKABLE bool updateItemDefinition(int id, const QVariantMap &data);
    Q_INVOKABLE bool deleteItemDefinition(int id);
    Q_INVOKABLE int saveItemDefinition(int id, const QVariantMap &itemData, const QVariantMap &weaponData);
    Q_INVOKABLE QVariantMap getWeaponDetails(int itemId);
    Q_INVOKABLE bool setWeaponDetails(int itemId, const QVariantMap &data);
    Q_INVOKABLE bool clearWeaponDetails(int itemId);
    Q_INVOKABLE QVariantMap getArmorDetails(int itemId);

    Q_INVOKABLE int addInventoryItem(int characterId, int itemId, int quantity = 1, int parentInventoryItemId = -1);
    Q_INVOKABLE bool updateInventoryItem(int id, const QVariantMap &data);
    Q_INVOKABLE bool removeInventoryItem(int id, Enums::RemovalMode mode = Enums::RemovalMode::SpillToParent, int destinationContainerId = -1);
    Q_INVOKABLE QVariantList getInventoryTree(int characterId);
    Q_INVOKABLE QVariantList getContainerContents(int inventoryItemId);

    Q_INVOKABLE double getTotalWeight(int characterId);
    Q_INVOKABLE double getCoinWeight(int characterId);
    Q_INVOKABLE double getCarryingCapacity(int characterId);
    Q_INVOKABLE double getContainerUsedWeight(int inventoryItemId);

private:
    void reportError(const QString &message);

    QJsonObject buildCharacterJson(int characterId);
    bool writeJsonObject(const QJsonObject &root, const QString &path);

    bool executeSql(const QString &sql);
    bool executeSqlFile(const QString &resourcePath);
    bool isNewDatabase();
    bool runSchema();
    bool runSeedData();
    bool isContainer(int inventoryItemId);
    int getItemOwner(int inventoryItemId);
    bool wouldCreateCycle(int itemId, int parentId);
    double interiorWeight(int rootId, int excludeItemId = -1);
    bool wouldExceedCapacity(int parentId, double additionalWeight, int excludeItemId = -1);

    QSqlDatabase m_db;
    bool m_initialized = false;
    QString m_lastError;
};

#endif // DATABASEMANAGER_H
