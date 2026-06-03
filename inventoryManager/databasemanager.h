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
    Q_INVOKABLE bool exportHomebrewPack(const QUrl &fileUrl, const QVariantList &itemIds = {});
    Q_INVOKABLE QString exportHomebrewPackJson(const QVariantList &itemIds = {});
    Q_INVOKABLE int importHomebrewPack(const QUrl &fileUrl);
    Q_INVOKABLE int importHomebrewPackFromJson(const QString &json);
    Q_INVOKABLE QStringList lastSkippedItems() const;
    Q_INVOKABLE QStringList lastSkippedCharacters() const;

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
    Q_INVOKABLE bool deleteItemDefinition(int id);
    Q_INVOKABLE int saveItemDefinition(int id, const QVariantMap &itemData,
                                        const QVariantMap &weaponData,
                                        const QVariantMap &armorData);
    Q_INVOKABLE QVariantMap getWeaponDetails(int itemId);
    Q_INVOKABLE QVariantMap getArmorDetails(int itemId);

    Q_INVOKABLE int addInventoryItem(int characterId, int itemId, int quantity = 1, int parentInventoryItemId = -1);
    Q_INVOKABLE bool updateInventoryItem(int id, const QVariantMap &data);
    Q_INVOKABLE bool removeInventoryItem(int id, Enums::RemovalMode mode = Enums::RemovalMode::SpillToParent, int destinationContainerId = -1);
    Q_INVOKABLE QVariantList getInventoryTree(int characterId);
    Q_INVOKABLE QVariantList getContainerContents(int inventoryItemId);

    Q_INVOKABLE QString buildInventoryItemShareJson(int inventoryItemId, int quantity);
    Q_INVOKABLE int importInventoryItemFromShare(const QString &payloadJson, int characterId);
    Q_INVOKABLE bool commitOutgoingShare(int inventoryItemId, int sharedQuantity);
    Q_INVOKABLE bool itemDefinitionExistsByName(const QString &name);

    Q_INVOKABLE double getTotalWeight(int characterId);
    Q_INVOKABLE double getCoinWeight(int characterId);
    Q_INVOKABLE double getCarryingCapacity(int characterId);
    Q_INVOKABLE double getContainerUsedWeight(int inventoryItemId);

    Q_INVOKABLE QVariantMap previewExtradimensionalRift(int itemDefinitionId, int parentInventoryItemId);
    Q_INVOKABLE QVariantMap previewMoveRift(int inventoryItemId, int parentInventoryItemId);
    Q_INVOKABLE bool destroyExtradimensionalRift(int targetInventoryItemId, int sourceInventoryItemId = -1);

private:
    void reportError(const QString &message);

    QJsonObject buildCharacterJson(int characterId);
    bool buildHomebrewPack(const QVariantList &itemIds, QJsonObject &out);
    QJsonObject buildInventoryItemShareNode(int inventoryItemId, int overrideQuantity = -1);
    int importInventoryItemNode(const QJsonObject &node, int characterId, int parentId);
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

    bool isExtradimensionalDef(int itemDefinitionId);
    int firstExtradimensionalAncestor(int inventoryItemId);
    QVariantList collectSubtreeNames(int rootInventoryItemId);

    int createItemDefinition(const QVariantMap &data);
    bool updateItemDefinition(int id, const QVariantMap &data);
    bool setWeaponDetails(int itemId, const QVariantMap &data);
    bool clearWeaponDetails(int itemId);
    bool setArmorDetails(int itemId, const QVariantMap &data);
    bool clearArmorDetails(int itemId);

    QSqlDatabase m_db;
    bool m_initialized = false;
    QString m_lastError;
    QStringList m_lastSkippedItems;
    QStringList m_lastSkippedCharacters;
};

#endif // DATABASEMANAGER_H
