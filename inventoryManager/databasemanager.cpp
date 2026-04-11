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
    QSqlQuery query(m_db);
    query.prepare(R"(INSERT INTO characters (name, level, strength, size, race, class, notes) VALUES (:name, :level, :strength, :size, :race, :class, :notes))");
    query.bindValue(":name", data.value("name"));
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

    QSqlQuery query(m_db);
    query.prepare("UPDATE characters SET " + assignments.join(", ") + " WHERE id = :id");
    query.bindValue(":id", id);
    for (auto it = data.constBegin(); it != data.constEnd(); ++it) {
        if (allowed.contains(it.key()))
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
    QSqlQuery query(m_db);
    query.prepare(R"(UPDATE character_coins SET cp=:cp, sp=:sp, ep=:ep, gp=:gp, pp=:pp WHERE character_id=:id)");
    query.bindValue(":id", characterId);
    query.bindValue(":cp", coins.value("cp",0));
    query.bindValue(":sp", coins.value("sp",0));
    query.bindValue(":ep", coins.value("ep",0));
    query.bindValue(":gp", coins.value("gp",0));
    query.bindValue(":pp", coins.value("pp",0));
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
    if (parentId > 0 && !isContainer(parentId)) {
        qWarning() << "addInventoryItem failed: parent" << parentId << "is not a container";
        return -1;
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
    int parentId = data.value("parent_inventory_item_id", -1).toInt();

    if (parentId > 0) {
        if (!isContainer(parentId)) {
            qWarning() << "updateInventoryItem failed: parent " << parentId << " is not a container";
            return false;
        }
        if (wouldCreateCycle(id, parentId)) {
            qWarning() << "updateInventoryItem failed: placing item " << id << " inside " << parentId << " would create a cycle";
            return false;
        }
    }

    QSqlQuery query(m_db);
    query.prepare(R"(UPDATE inventory_items SET quantity=:quantity, parent_inventory_item_id =:parentId, is_equipped = :isEquipped, custom_name = :customName, notes=:notes WHERE id=:id)");
    query.bindValue(":id", id);
    query.bindValue(":quantity", data.value("quantity", 1));
    query.bindValue(":isEquipped", data.value("is_equipped", 0));
    query.bindValue(":customName", data.value("custom_name"));
    query.bindValue(":notes", data.value("notes"));
    query.bindValue(":parentId", parentId > 0 ? parentId : QVariant());

    if (!query.exec()) {
        qWarning() << "updateInventoryItem failed: " << query.lastError().text();
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool DatabaseManager::removeInventoryItem(int id)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM inventory_items WHERE id=:id");
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
    //count everything
    //add fixed weight containers later
    QSqlQuery query(m_db);
    query.prepare(R"(SELECT COALESCE(SUM(idef.weight_lb * ii.quantity), 0.0) FROM inventory_items ii JOIN item_definitions idef ON ii.item_id = idef.id WHERE ii.character_id = :characterId)");
    query.bindValue(":characterId", characterId);
    if (!query.exec() || !query.next())
        return 0.0;
    return query.value(0).toDouble();
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
    QSqlQuery query(m_db);
    query.prepare(R"(SELECT COALESCE(SUM(idef.weight_lb * ii.quantity), 0.0) FROM inventory_items ii JOIN item_definitions idef ON ii.item_id = idef.id
    WHERE ii.parent_inventory_item_id=:parentId)");
    query.bindValue(":parentId", inventoryItemId);
    if (!query.exec()|| !query.next())
        return 0.0;
    return query.value(0).toDouble();
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