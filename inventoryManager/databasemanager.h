#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QtSql/QSqlDatabase>
#include <QFileInfo>
#include <QDir>

#include "enums.h"

class DatabaseManager : public QObject
{
    Q_OBJECT
public:
    explicit DatabaseManager(QObject *parent = nullptr);
    ~DatabaseManager();

    bool initialize(const QString &dbPath);
    bool isInitialized() const;

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
    QVariantMap getWeaponDetails(int itemId);
    QVariantMap getArmorDetails(int itemId);

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
};

#endif // DATABASEMANAGER_H
