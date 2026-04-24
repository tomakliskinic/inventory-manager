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

    int createCharacter(const QVariantMap &data);
    bool updateCharacter(int id, const QVariantMap &data);
    bool deleteCharacter(int id);
    QVariantMap getCharacter(int id);
    QVariantList getAllCharacters();

    QVariantMap getCoins(int characterId);
    bool updateCoins(int characterId, const QVariantMap &coins);

    QVariantList getItemDefinitions (int itemType = -1);
    QVariantMap getItemDefinition(int id);
    QVariantMap getWeaponDetails(int itemId);
    QVariantMap getArmorDetails(int itemId);

    int addInventoryItem(int characterId, int itemId, int quantity = 1, int parentInventoryItemId = -1);
    bool updateInventoryItem(int id, const QVariantMap &data);
    bool removeInventoryItem(int id, Enums::RemovalMode mode = Enums::RemovalMode::SpillToParent, int destinationContainerId = -1);
    QVariantList getInventoryTree(int characterId);
    QVariantList getContainerContents(int inventoryItemId);

    double getTotalWeight(int characterId);
    double getCoinWeight(int characterId);
    double getCarryingCapacity(int characterId);
    double getContainerUsedWeight(int inventoryItemId);

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
