#include "databasemanager.h"
#include "enums.h"

#include <QtSql/QSqlQuery>
#include <QtSql/QSqlError>
#include <QtSql/QSqlRecord>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>

DatabaseManager::DatabaseManager(QObject *parent) : QObject(parent) {}

DatabaseManager::~DatabaseManager()
{
    if (m_db.isOpen())
        m_db.close();
}

bool DatabaseManager::initialize(const QString &dbPath)
{
    QFileInfo fi(dbPath);
    QDir dir;
    if (!dir.mkpath(fi.absolutePath())) {
        qWarning() << "Cannot create database directory: "<< fi.absolutePath();
        return false;
    }

    m_db = QSqlDatabase::addDatabase("QSQLITE");
    qDebug() << "Database path:" << dbPath;
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qWarning() << "Cannot open database: " <<m_db.lastError().text();
        return false;
    }

    executeSql("PRAGMA foreign_keys = ON");

    if (isNewDatabase()) {
        qInfo() << "New database detected, running schema and seed...";

        if (!runSchema()) {
            qWarning() << "Schema creation failed";
            return false;
        }

        qDebug() << "Schema done, starting seed...";

        if (!runSeedData()) {
            qWarning() << "Seed data failed";
            return false;
        }

        qDebug() << "Seed done, items:" << getItemDefinitions().count();
    }

    m_initialized = true;
    return true;
}

bool DatabaseManager::isInitialized() const
{
    return m_initialized;
}

int DatabaseManager::createCharacter(const QVariantMap &data)
{
    QString name = data.value("name").toString().trimmed();
    if (name.isEmpty()) {
        qWarning() << "createCharacter failed: name is required";
        return -1;
    }

    QSqlQuery query(m_db);
    query.prepare(R"(INSERT INTO characters (name, level, strength, size, race, class, notes) VALUES (:name, :level, :strength, :size, :race, :class, :notes))");
    query.bindValue(":name", name);
    query.bindValue(":level", data.value("level", 1));
    query.bindValue(":strength", data.value("strength", 10));
    query.bindValue(":size", data.value("size", static_cast<int>(Enums::CreatureSize::Medium)));
    query.bindValue(":race", data.value("race"));
    query.bindValue(":class", data.value("class"));
    query.bindValue(":notes", data.value("notes"));

    if (!query.exec()) {
        qWarning() << "CreateCharacter failed: " << query.lastError().text();
        return -1;
    }

    return query.lastInsertId().toInt();
}

bool DatabaseManager::updateCharacter(int id, const QVariantMap &data)
{
    static const QStringList allowed = {"name", "level", "strength", "size", "race", "class", "notes"};

    QStringList assignments;
    for (const QString &field : allowed) {
        if (data.contains(field))
            assignments << field + " = :" + field;
    }

    if (assignments.isEmpty())
        return false;

    QString trimmedName;
    if (data.contains("name")) {
        trimmedName = data.value("name").toString().trimmed();
        if (trimmedName.isEmpty()) {
            qWarning() << "updateCharacter failed: name cannot be empty";
            return false;
        }
    }

    QSqlQuery query(m_db);
    query.prepare("UPDATE characters SET " + assignments.join(", ") + " WHERE id = :id");
    query.bindValue(":id", id);
    for (auto it = data.constBegin(); it != data.constEnd(); ++it) {
        if (!allowed.contains(it.key()))
            continue;
        if (it.key() == "name")
            query.bindValue(":name", trimmedName);
        else
            query.bindValue(":" + it.key(), it.value());
    }

    if (!query.exec()) {
        qWarning() << "updateCharacter failed: " << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool DatabaseManager::deleteCharacter(int id)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM characters WHERE id = :id");
    query.bindValue(":id", id);
    if (!query.exec()) {
        qWarning() << "deleteCharacter failed: " << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

QVariantMap DatabaseManager::getCharacter(int id)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT * FROM characters WHERE id = :id");
    query.bindValue(":id", id);
    if (!query.exec() || !query.next())
        return {};
    QVariantMap map;
    QSqlRecord record = query.record();
    for (int i=0; i<record.count(); i++)
        map.insert(record.fieldName(i), query.value(i));
    return map;
}

QVariantList DatabaseManager::getAllCharacters()
{
    QVariantList list;
    QSqlQuery query(m_db);
    if (!query.exec("SELECT * FROM characters ORDER BY name")) {
        qWarning() << "getAllCharacters failed: " << query.lastError().text();
        return list;
    }
    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i=0; i<record.count(); i++)
            map.insert(record.fieldName(i), query.value(i));
        list.append(map);
    }
    return list;
}

QVariantMap DatabaseManager::getCoins(int characterId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT cp, sp, ep, gp, pp FROM character_coins WHERE character_id = :id");
    query.bindValue(":id", characterId);
    if (!query.exec() || !query.next())
        return {};
    return {
        {"cp", query.value(0)},
        {"sp", query.value(1)},
        {"ep", query.value(2)},
        {"gp", query.value(3)},
        {"pp", query.value(4)},
        };
}

bool DatabaseManager::updateCoins(int characterId, const QVariantMap &coins)
{
    static const QStringList allowed = {"cp", "sp", "ep", "gp", "pp"};

    QStringList assignments;
    for (const QString &field : allowed) {
        if (coins.contains(field))
            assignments << field + " = :" + field;
    }

    if (assignments.isEmpty())
        return false;

    QSqlQuery query(m_db);
    query.prepare("UPDATE character_coins SET " + assignments.join(", ") + " WHERE character_id = :id");
    query.bindValue(":id", characterId);
    for (auto it = coins.constBegin(); it != coins.constEnd(); ++it) {
        if (allowed.contains(it.key()))
            query.bindValue(":" + it.key(), it.value());
    }

    if (!query.exec()) {
        qWarning() << "updateCoins failed: " << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

QVariantList DatabaseManager::getItemDefinitions(int itemType)
{
    QVariantList list;
    QSqlQuery query(m_db);

    if (itemType >= 0) {
        query.prepare("SELECT * FROM item_definitions WHERE item_type=:type ORDER BY name");
        query.bindValue(":type", itemType);
    }
    else
        query.prepare("SELECT * FROM item_definitions ORDER BY name");

    if (!query.exec()) {
        qWarning() << "getItemDefinitions failed: " << query.lastError().text();
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i=0; i<record.count(); i++)
            map.insert(record.fieldName(i), query.value(i));
        list.append(map);
    }

    return list;
}

QVariantMap DatabaseManager::getItemDefinition(int id)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT * FROM item_definitions WHERE id=:id");
    query.bindValue(":id", id);
    if (!query.exec() || !query.next())
        return {};

    QVariantMap map;
    QSqlRecord record = query.record();
    for (int i=0; i<record.count(); i++)
        map.insert(record.fieldName(i), query.value(i));
    return map;
}

QVariantMap DatabaseManager::getWeaponDetails(int itemId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT * FROM weapon_details WHERE item_id=:id");
    query.bindValue(":id", itemId);
    if (!query.exec() || !query.next())
        return {};

    QVariantMap map;
    QSqlRecord record = query.record();
    for (int i=0; i<record.count(); i++)
        map.insert(record.fieldName(i), query.value(i));
    return map;
}

QVariantMap DatabaseManager::getArmorDetails(int itemId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT * FROM armor_details WHERE item_id=:id");
    query.bindValue(":id", itemId);
    if (!query.exec() || !query.next())
        return {};

    QVariantMap map;
    QSqlRecord record = query.record();
    for (int i=0; i<record.count(); i++)
        map.insert(record.fieldName(i), query.value(i));
    return map;
}

int DatabaseManager::addInventoryItem(int characterId, int itemId, int quantity, int parentId)
{
    if (parentId > 0) {
        if (!isContainer(parentId)) {
            qWarning() << "addInventoryItem failed: parent" << parentId << "is not a container";
            return -1;
        }
        if (getItemOwner(parentId) != characterId) {
            qWarning() << "addInventoryItem failed: parent" << parentId << "belongs to a different character";
            return -1;
        }

        QSqlQuery weightQuery(m_db);
        weightQuery.prepare("SELECT COALESCE(fixed_weight, weight_lb) FROM item_definitions WHERE id = :id");
        weightQuery.bindValue(":id", itemId);
        if (!weightQuery.exec() || !weightQuery.next()) {
            qWarning() << "addInventoryItem failed: item definition" << itemId << "not found";
            return -1;
        }
        double additional = weightQuery.value(0).toDouble() * quantity;

        if (wouldExceedCapacity(parentId, additional)) {
            qWarning() << "addInventoryItem failed: container chain would exceed weight capacity";
            return -1;
        }
    }

    QSqlQuery query(m_db);
    query.prepare(R"(INSERT INTO inventory_items (character_id, item_id, quantity, parent_inventory_item_id) VALUES (:characterId, :itemId, :quantity, :parentId))");
    query.bindValue(":characterId", characterId);
    query.bindValue(":itemId", itemId);
    query.bindValue(":quantity", quantity);
    query.bindValue(":parentId", parentId > 0 ? parentId : QVariant());
    if (!query.exec()) {
        qWarning() << "addInventoryItem failed: " << query.lastError().text();
        return -1;
    }

    return query.lastInsertId().toInt();

}

bool DatabaseManager::updateInventoryItem(int id, const QVariantMap &data)
{
    static const QStringList allowed = {"quantity", "parent_inventory_item_id", "is_equipped", "custom_name", "notes"};

    QStringList assignments;
    for (const QString &field : allowed) {
        if (data.contains(field))
            assignments << field + " = :" + field;
    }

    if (assignments.isEmpty())
        return false;

    const bool parentChanging = data.contains("parent_inventory_item_id");
    const bool quantityChanging = data.contains("quantity");

    if (parentChanging || quantityChanging) {
        QSqlQuery current(m_db);
        current.prepare("SELECT quantity, parent_inventory_item_id FROM inventory_items WHERE id = :id");
        current.bindValue(":id", id);
        if (!current.exec() || !current.next()) {
            qWarning() << "updateInventoryItem failed: item" << id << "not found";
            return false;
        }
        int effectiveQty = quantityChanging ? data.value("quantity").toInt() : current.value(0).toInt();
        QVariant currentParentVal = current.value(1);
        int effectiveParent = parentChanging
            ? data.value("parent_inventory_item_id", -1).toInt()
            : (currentParentVal.isNull() ? -1 : currentParentVal.toInt());

        if (effectiveParent > 0) {
            if (parentChanging) {
                if (!isContainer(effectiveParent)) {
                    qWarning() << "updateInventoryItem failed: parent" << effectiveParent << "is not a container";
                    return false;
                }
                if (getItemOwner(effectiveParent) != getItemOwner(id)) {
                    qWarning() << "updateInventoryItem failed: parent" << effectiveParent << "belongs to a different character";
                    return false;
                }
                if (wouldCreateCycle(id, effectiveParent)) {
                    qWarning() << "updateInventoryItem failed: placing item" << id << "inside" << effectiveParent << "would create a cycle";
                    return false;
                }
            }

            QSqlQuery lookup(m_db);
            lookup.prepare(R"(SELECT COALESCE(idef.fixed_weight, idef.weight_lb)
                FROM inventory_items ii
                JOIN item_definitions idef ON ii.item_id = idef.id
                WHERE ii.id = :id)");
            lookup.bindValue(":id", id);
            if (!lookup.exec() || !lookup.next()) {
                qWarning() << "updateInventoryItem failed: item" << id << "not found";
                return false;
            }
            double additional = lookup.value(0).toDouble() * effectiveQty + interiorWeight(id);

            if (wouldExceedCapacity(effectiveParent, additional, id)) {
                qWarning() << "updateInventoryItem failed: container chain would exceed weight capacity";
                return false;
            }
        }
    }

    QSqlQuery query(m_db);
    query.prepare("UPDATE inventory_items SET " + assignments.join(", ") + " WHERE id = :id");
    query.bindValue(":id", id);
    for (auto it = data.constBegin(); it != data.constEnd(); ++it) {
        if (!allowed.contains(it.key()))
            continue;
        if (it.key() == "parent_inventory_item_id") {
            int p = it.value().toInt();
            query.bindValue(":parent_inventory_item_id", p > 0 ? QVariant(p) : QVariant());
        } else {
            query.bindValue(":" + it.key(), it.value());
        }
    }

    if (!query.exec()) {
        qWarning() << "updateInventoryItem failed: " << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool DatabaseManager::removeInventoryItem(int id, Enums::RemovalMode mode, int destinationContainerId)
{
    QSqlQuery childCheck(m_db);
    childCheck.prepare("SELECT COUNT(*) FROM inventory_items WHERE parent_inventory_item_id = :id");
    childCheck.bindValue(":id", id);
    if (!childCheck.exec() || !childCheck.next())
        return false;

    int childCount = childCheck.value(0).toInt();

    if (childCount > 0) {
        QSqlQuery parentQuery(m_db);
        parentQuery.prepare("SELECT parent_inventory_item_id FROM inventory_items WHERE id = :id");
        parentQuery.bindValue(":id", id);
        if (!parentQuery.exec() || !parentQuery.next())
            return false;
        QVariant parentVal = parentQuery.value(0);
        int parentId = parentVal.isNull() ? -1 : parentVal.toInt();

        switch (mode) {
        case Enums::RemovalMode::SpillToParent: {
            if (parentId > 0) {
                double contentsWeight = interiorWeight(id);
                if (wouldExceedCapacity(parentId, contentsWeight, id)) {
                    qWarning() << "removeInventoryItem failed: spilling contents would exceed parent container capacity";
                    return false;
                }
            }

            QSqlQuery reparent(m_db);
            reparent.prepare("UPDATE inventory_items SET parent_inventory_item_id = :newParent WHERE parent_inventory_item_id = :id");
            reparent.bindValue(":newParent", parentId > 0 ? QVariant(parentId) : QVariant());
            reparent.bindValue(":id", id);
            if (!reparent.exec()) {
                qWarning() << "removeInventoryItem failed: could not reparent children";
                return false;
            }
            break;
        }
        case Enums::RemovalMode::DeleteAll: {
            QSqlQuery deleteChildren(m_db);
            deleteChildren.prepare(R"(
                WITH RECURSIVE descendants AS (
                    SELECT id FROM inventory_items WHERE parent_inventory_item_id = :id
                    UNION ALL
                    SELECT ii.id FROM inventory_items ii
                    JOIN descendants d ON ii.parent_inventory_item_id = d.id
                )
                DELETE FROM inventory_items WHERE id IN (SELECT id FROM descendants))");
            deleteChildren.bindValue(":id", id);
            if (!deleteChildren.exec()) {
                qWarning() << "removeInventoryItem failed: could not delete children";
                return false;
            }
            break;
        }
        case Enums::RemovalMode::MoveToContainer: {
            if (destinationContainerId <= 0) {
                qWarning() << "removeInventoryItem failed: destination container required for MoveToContainer mode";
                return false;
            }
            if (!isContainer(destinationContainerId)) {
                qWarning() << "removeInventoryItem failed: destination" << destinationContainerId << "is not a container";
                return false;
            }
            if (getItemOwner(destinationContainerId) != getItemOwner(id)) {
                qWarning() << "removeInventoryItem failed: destination" << destinationContainerId << "belongs to a different character";
                return false;
            }
            if (wouldCreateCycle(id, destinationContainerId)) {
                qWarning() << "removeInventoryItem failed: destination is inside the container being removed";
                return false;
            }

            double contentsWeight = interiorWeight(id);
            if (wouldExceedCapacity(destinationContainerId, contentsWeight)) {
                qWarning() << "removeInventoryItem failed: contents would exceed destination container capacity";
                return false;
            }

            QSqlQuery reparent(m_db);
            reparent.prepare("UPDATE inventory_items SET parent_inventory_item_id = :newParent WHERE parent_inventory_item_id = :id");
            reparent.bindValue(":newParent", destinationContainerId);
            reparent.bindValue(":id", id);
            if (!reparent.exec()) {
                qWarning() << "removeInventoryItem failed: could not move children to destination";
                return false;
            }
            break;
        }
        }
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM inventory_items WHERE id = :id");
    query.bindValue(":id", id);
    if (!query.exec()) {
        qWarning() << "removeInventoryItem failed: " << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

QVariantList DatabaseManager::getInventoryTree(int characterId)
{
    QVariantList list;
    QSqlQuery query(m_db);

    query.prepare(R"(WITH RECURSIVE tree AS (SELECT ii.id, ii.item_id, ii.quantity, ii.parent_inventory_item_id, ii.is_equipped, ii.custom_name, ii.notes,
    idef.name AS item_name, idef.item_type, idef.weight_lb, idef.is_container, idef.container_weight_capacity, idef.fixed_weight, 0 AS depth FROM inventory_items ii
    JOIN item_definitions idef ON ii.item_id = idef.id WHERE ii.character_id = :characterId AND ii.parent_inventory_item_id IS NULL UNION ALL
    SELECT ii.id, ii.item_id, ii.quantity, ii.parent_inventory_item_id, ii.is_equipped, ii.custom_name, ii.notes,
    idef.name, idef.item_type, idef.weight_lb, idef.is_container, idef.container_weight_capacity, idef.fixed_weight, t.depth +1
    FROM inventory_items ii JOIN item_definitions idef ON ii.item_id = idef.id JOIN tree t ON ii.parent_inventory_item_id = t.id)
    SELECT * FROM tree ORDER BY depth, item_name)");
    query.bindValue(":characterId", characterId);
    if (!query.exec()) {
        qWarning() << "getInventoryTree failed " << query.lastError().text();
        return list;
    }
    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i=0; i< record.count(); i++)
            map.insert(record.fieldName(i), query.value(i));
        list.append(map);
    }
    return list;
}

QVariantList DatabaseManager::getContainerContents(int inventoryItemId)
{
    QVariantList list;
    QSqlQuery query(m_db);
    query.prepare(R"(SELECT ii.*, idef.name AS item_name, idef.weight_lb, idef.is_container FROM inventory_items ii JOIN item_definitions idef
    ON ii.item_id = idef.id WHERE ii.parent_inventory_item_id = :parentId ORDER BY idef.name)");
    query.bindValue(":parentId", inventoryItemId);
    if (!query.exec()) {
        qWarning() << "getContainerContents failed: " << query.lastError().text();
        return list;
    }

    while (query.next()) {
        QVariantMap map;
        QSqlRecord record = query.record();
        for (int i=0; i<record.count(); i++)
            map.insert(record.fieldName(i), query.value(i));
        list.append(map);
    }
    return list;
}

double DatabaseManager::getTotalWeight(int characterId)
{
    QSqlQuery query(m_db);
    query.prepare(R"(WITH RECURSIVE tree AS (
        SELECT ii.id, ii.quantity, idef.weight_lb, idef.fixed_weight
        FROM inventory_items ii
        JOIN item_definitions idef ON ii.item_id = idef.id
        WHERE ii.character_id = :characterId AND ii.parent_inventory_item_id IS NULL
        UNION ALL
        SELECT ii.id, ii.quantity, idef.weight_lb, idef.fixed_weight
        FROM inventory_items ii
        JOIN item_definitions idef ON ii.item_id = idef.id
        JOIN tree t ON ii.parent_inventory_item_id = t.id
        WHERE t.fixed_weight IS NULL
    )
    SELECT COALESCE(SUM(COALESCE(fixed_weight, weight_lb) * quantity), 0.0) FROM tree)");
    query.bindValue(":characterId", characterId);
    if (!query.exec() || !query.next())
        return 0.0;
    return query.value(0).toDouble() + getCoinWeight(characterId);
}

double DatabaseManager::getCoinWeight(int characterId)
{
    QSqlQuery query(m_db);
    query.prepare(R"(SELECT (cp + sp + ep + gp + pp) / 50.0 FROM character_coins WHERE character_id = :characterId)");
    query.bindValue(":characterId", characterId);
    if (!query.exec() || !query.next())
        return 0.0;
    return query.value(0).toDouble();
}

double DatabaseManager::getCarryingCapacity(int characterId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT strength, size FROM characters WHERE id=:id");
    query.bindValue(":id", characterId);
    if (!query.exec() || !query.next())
        return 0.0;
    int strength = query.value(0).toInt();
    auto size = static_cast<Enums::CreatureSize>(query.value(1).toInt());
    return Enums::carryMultiplier(size) * strength;
}

double DatabaseManager::getContainerUsedWeight(int inventoryItemId)
{
    return interiorWeight(inventoryItemId);
}

bool DatabaseManager::executeSql(const QString &sql)
{
    QSqlQuery query(m_db);
    if (!query.exec(sql)) {
        qWarning() << "SQL execution failed: " << query.lastError().text() << "\nQuery: " << sql.left(200);
        return false;
    }
    return true;
}

bool DatabaseManager::executeSqlFile(const QString &resourcePath)
{
    QFile file(resourcePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Cannot open SQL file:" << resourcePath;
        return false;
    }

    QString sql = file.readAll();
    file.close();
    QStringList statements;
    QString current;
    bool insideBlock = false;

    for (const QString &line : sql.split('\n')) {
        QString trimmed = line.trimmed();
        if (trimmed.isEmpty() || trimmed.startsWith("--"))
            continue;

        current += line + '\n';

        if (trimmed.toUpper() == "BEGIN") {
            insideBlock = true;
        } else if (trimmed.toUpper().startsWith("END;")) {
            insideBlock = false;
            statements.append(current.trimmed());
            current.clear();
        } else if (!insideBlock && trimmed.endsWith(';')) {
            statements.append(current.trimmed());
            current.clear();
        }
    }

    QSqlQuery query(m_db);
    for (const QString &stmt : statements) {
        if (!query.exec(stmt)) {
            qWarning() << "Failed:" << resourcePath << query.lastError().text()
            << "\nStatement:" << stmt.left(200);
            return false;
        }
    }

    return true;
}

bool DatabaseManager::isNewDatabase()
{
    QSqlQuery query(m_db);
    query.exec("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='characters'");
    if (query.next())
        return query.value(0).toInt() == 0;
    return true;
}

bool DatabaseManager::runSchema()
{
    return executeSqlFile(":/sql/00_full_schema.sql");
}

bool DatabaseManager::runSeedData()
{
    const QStringList seeds = {
       ":/sql/seed_01_weapons.sql",
        ":/sql/seed_02_armor.sql",
        ":/sql/seed_03_gear.sql",
        ":/sql/seed_04_tools.sql",
        ":/sql/seed_05_magic.sql",
    };

    for (const QString &seed : seeds) {
        qDebug() << "Loading seed:" << seed << "exists:" << QFile::exists(seed);
        if (!executeSqlFile(seed))
            return false;
    }
    return true;
}

bool DatabaseManager::isContainer(int inventoryItemId)
{
    QSqlQuery query(m_db);
    query.prepare(R"(SELECT idef.is_container FROM inventory_items ii JOIN item_definitions idef ON ii.item_id = idef.id WHERE ii.id = :id)");
    query.bindValue(":id", inventoryItemId);
    if (!query.exec() || !query.next())
        return false;
    return query.value(0).toBool();
}

int DatabaseManager::getItemOwner(int inventoryItemId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT character_id FROM inventory_items WHERE id = :id");
    query.bindValue(":id", inventoryItemId);
    if (!query.exec() || !query.next())
        return -1;
    return query.value(0).toInt();
}

bool DatabaseManager::wouldCreateCycle(int itemId, int parentId)
{
    int current = parentId;
    while (current > 0) {
        if (current == itemId)
            return true;
        QSqlQuery query(m_db);
        query.prepare("SELECT parent_inventory_item_id FROM inventory_items WHERE id = :id");
        query.bindValue(":id", current);
        if (!query.exec() || !query.next())
            return false;
        QVariant val = query.value(0);
        current = val.isNull() ? -1 : val.toInt();
    }
    return false;
}

double DatabaseManager::interiorWeight(int rootId, int excludeItemId)
{
    QString sql =
        "WITH RECURSIVE tree AS ("
        "  SELECT ii.id, ii.quantity, idef.weight_lb, idef.fixed_weight "
        "  FROM inventory_items ii "
        "  JOIN item_definitions idef ON ii.item_id = idef.id "
        "  WHERE ii.parent_inventory_item_id = :rootId";
    if (excludeItemId > 0)
        sql += " AND ii.id != :excludeId";
    sql +=
        "  UNION ALL "
        "  SELECT ii.id, ii.quantity, idef.weight_lb, idef.fixed_weight "
        "  FROM inventory_items ii "
        "  JOIN item_definitions idef ON ii.item_id = idef.id "
        "  JOIN tree t ON ii.parent_inventory_item_id = t.id "
        "  WHERE t.fixed_weight IS NULL";
    if (excludeItemId > 0)
        sql += " AND ii.id != :excludeId";
    sql +=
        ") SELECT COALESCE(SUM(COALESCE(fixed_weight, weight_lb) * quantity), 0.0) FROM tree";

    QSqlQuery query(m_db);
    query.prepare(sql);
    query.bindValue(":rootId", rootId);
    if (excludeItemId > 0)
        query.bindValue(":excludeId", excludeItemId);
    if (!query.exec() || !query.next())
        return 0.0;
    return query.value(0).toDouble();
}

bool DatabaseManager::wouldExceedCapacity(int parentId, double additionalWeight, int excludeItemId)
{
    int current = parentId;
    while (current > 0) {
        QSqlQuery query(m_db);
        query.prepare(R"(SELECT idef.container_weight_capacity, idef.fixed_weight, ii.parent_inventory_item_id
            FROM inventory_items ii
            JOIN item_definitions idef ON ii.item_id = idef.id
            WHERE ii.id = :id)");
        query.bindValue(":id", current);
        if (!query.exec() || !query.next())
            return false;
        QVariant capVal = query.value(0);
        QVariant fwVal = query.value(1);
        QVariant parentVal = query.value(2);

        if (!capVal.isNull()) {
            double capacity = capVal.toDouble();
            double used = interiorWeight(current, excludeItemId);
            if (used + additionalWeight > capacity)
                return true;
        }

        if (!fwVal.isNull())
            break;

        current = parentVal.isNull() ? -1 : parentVal.toInt();
    }
    return false;
}