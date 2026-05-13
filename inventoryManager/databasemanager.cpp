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
#include <QMetaEnum>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QDateTime>
#include <QUrl>
#include <functional>

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

QString DatabaseManager::lastError() const
{
    return m_lastError;
}

void DatabaseManager::reportError(const QString &message)
{
    m_lastError = message;
    qWarning().noquote() << message;
}

QJsonObject DatabaseManager::buildCharacterJson(int characterId)
{
    const QVariantMap c = getCharacter(characterId);
    if (c.isEmpty()) return QJsonObject();

    QJsonObject character;
    character["name"] = c.value("name").toString();
    character["level"] = c.value("level").toInt();
    character["strength"] = c.value("strength").toInt();
    character["size"] = c.value("size").toInt();
    if (!c.value("race").toString().isEmpty())
        character["race"] = c.value("race").toString();
    if (!c.value("class").toString().isEmpty())
        character["class"] = c.value("class").toString();
    if (!c.value("notes").toString().isEmpty())
        character["notes"] = c.value("notes").toString();

    const QVariantMap coins = getCoins(characterId);
    QJsonObject coinsObj;
    coinsObj["cp"] = coins.value("cp").toInt();
    coinsObj["sp"] = coins.value("sp").toInt();
    coinsObj["ep"] = coins.value("ep").toInt();
    coinsObj["gp"] = coins.value("gp").toInt();
    coinsObj["pp"] = coins.value("pp").toInt();
    character["coins"] = coinsObj;

    const QVariantList allItems = getInventoryTree(characterId);
    std::function<QJsonArray(int)> buildChildren = [&](int parentId) -> QJsonArray {
        QJsonArray arr;
        for (const QVariant &iv : allItems) {
            const QVariantMap item = iv.toMap();
            const QVariant parentVar = item.value("parent_inventory_item_id");
            const int itemParent = (parentVar.isValid() && !parentVar.isNull())
                ? parentVar.toInt() : 0;
            if (itemParent != parentId) continue;

            QJsonObject obj;
            obj["item"] = item.value("item_name").toString();
            obj["quantity"] = item.value("quantity").toInt();
            if (item.value("is_equipped").toInt() != 0)
                obj["is_equipped"] = 1;
            const QVariant cn = item.value("custom_name");
            if (cn.isValid() && !cn.isNull() && !cn.toString().isEmpty())
                obj["custom_name"] = cn.toString();
            const QVariant nt = item.value("notes");
            if (nt.isValid() && !nt.isNull() && !nt.toString().isEmpty())
                obj["notes"] = nt.toString();

            const QJsonArray children = buildChildren(item.value("id").toInt());
            if (!children.isEmpty())
                obj["children"] = children;

            arr.append(obj);
        }
        return arr;
    };
    character["inventory"] = buildChildren(0);
    return character;
}

bool DatabaseManager::writeJsonObject(const QJsonObject &root, const QString &path)
{
    if (path.isEmpty()) {
        reportError(QStringLiteral("export failed: invalid file path"));
        return false;
    }
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        reportError(QStringLiteral("export failed: cannot write to %1").arg(path));
        return false;
    }
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    file.close();
    return true;
}

bool DatabaseManager::exportAllToFile(const QUrl &fileUrl)
{
    QJsonObject root;
    root["version"] = 1;
    root["exported_at"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    QJsonArray charactersArray;
    for (const QVariant &cv : getAllCharacters()) {
        const QVariantMap c = cv.toMap();
        charactersArray.append(buildCharacterJson(c.value("id").toInt()));
    }
    root["characters"] = charactersArray;

    return writeJsonObject(root, fileUrl.toLocalFile());
}

bool DatabaseManager::exportCharacterToFile(int characterId, const QUrl &fileUrl)
{
    const QJsonObject character = buildCharacterJson(characterId);
    if (character.isEmpty()) {
        reportError(QStringLiteral("exportCharacterToFile failed: character %1 not found").arg(characterId));
        return false;
    }

    QJsonObject root;
    root["version"] = 1;
    root["exported_at"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    QJsonArray charactersArray;
    charactersArray.append(character);
    root["characters"] = charactersArray;

    return writeJsonObject(root, fileUrl.toLocalFile());
}

int DatabaseManager::importFromFile(const QUrl &fileUrl)
{
    const QString path = fileUrl.toLocalFile();
    if (path.isEmpty()) {
        reportError(QStringLiteral("importFromFile failed: invalid file path"));
        return -1;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        reportError(QStringLiteral("importFromFile failed: cannot read %1").arg(path));
        return -1;
    }
    const QByteArray data = file.readAll();
    file.close();

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError) {
        reportError(QStringLiteral("importFromFile failed: %1").arg(err.errorString()));
        return -1;
    }
    if (!doc.isObject()) {
        reportError(QStringLiteral("importFromFile failed: root is not a JSON object"));
        return -1;
    }

    const QJsonObject root = doc.object();
    if (!root.contains("characters") || !root["characters"].isArray()) {
        reportError(QStringLiteral("importFromFile failed: missing 'characters' array"));
        return -1;
    }

    if (!m_db.transaction()) {
        qWarning() << "importFromFile failed: could not begin transaction:" << m_db.lastError().text();
        return -1;
    }

    int imported = 0;
    const QJsonArray characters = root["characters"].toArray();
    for (const QJsonValue &cv : characters) {
        if (!cv.isObject()) continue;
        const QJsonObject c = cv.toObject();

        QVariantMap charData;
        charData["name"] = c["name"].toString();
        charData["level"] = c["level"].toInt(1);
        charData["strength"] = c["strength"].toInt(10);
        charData["size"] = c["size"].toInt(static_cast<int>(Enums::CreatureSize::Medium));
        if (c.contains("race")) charData["race"] = c["race"].toString();
        if (c.contains("class")) charData["class"] = c["class"].toString();
        if (c.contains("notes")) charData["notes"] = c["notes"].toString();

        const int charId = createCharacter(charData);
        if (charId < 0) {
            m_db.rollback();
            return -1;
        }

        if (c.contains("coins") && c["coins"].isObject()) {
            const QJsonObject coinsObj = c["coins"].toObject();
            QVariantMap coinsData;
            coinsData["cp"] = coinsObj["cp"].toInt();
            coinsData["sp"] = coinsObj["sp"].toInt();
            coinsData["ep"] = coinsObj["ep"].toInt();
            coinsData["gp"] = coinsObj["gp"].toInt();
            coinsData["pp"] = coinsObj["pp"].toInt();
            updateCoins(charId, coinsData);
        }

        if (c.contains("inventory") && c["inventory"].isArray()) {
            QSqlQuery insertItem(m_db);
            insertItem.prepare(R"(INSERT INTO inventory_items
                (character_id, item_id, quantity, parent_inventory_item_id, is_equipped, custom_name, notes)
                VALUES (:char, :item, :qty, :parent, :eq, :cn, :notes))");

            QSqlQuery lookupItem(m_db);
            lookupItem.prepare("SELECT id FROM item_definitions WHERE name = :name");

            std::function<bool(const QJsonArray &, int)> addItems =
                [&](const QJsonArray &items, int parentId) -> bool {
                for (const QJsonValue &iv : items) {
                    if (!iv.isObject()) continue;
                    const QJsonObject item = iv.toObject();

                    const QString itemName = item["item"].toString();
                    if (itemName.isEmpty()) continue;

                    lookupItem.bindValue(":name", itemName);
                    if (!lookupItem.exec() || !lookupItem.next()) {
                        qWarning() << "importFromFile: skipping unknown item" << itemName;
                        continue;
                    }
                    const int itemId = lookupItem.value(0).toInt();

                    insertItem.bindValue(":char", charId);
                    insertItem.bindValue(":item", itemId);
                    insertItem.bindValue(":qty", item.value("quantity").toInt(1));
                    insertItem.bindValue(":parent", parentId > 0 ? QVariant(parentId) : QVariant());
                    insertItem.bindValue(":eq", item.value("is_equipped").toInt(0));
                    const bool hasCn = item.contains("custom_name") && !item["custom_name"].isNull();
                    insertItem.bindValue(":cn", hasCn ? QVariant(item["custom_name"].toString()) : QVariant());
                    const bool hasNotes = item.contains("notes") && !item["notes"].isNull();
                    insertItem.bindValue(":notes", hasNotes ? QVariant(item["notes"].toString()) : QVariant());

                    if (!insertItem.exec()) {
                        qWarning() << "importFromFile failed:" << insertItem.lastError().text();
                        return false;
                    }
                    const int newId = insertItem.lastInsertId().toInt();

                    if (item.contains("children") && item["children"].isArray()) {
                        if (!addItems(item["children"].toArray(), newId))
                            return false;
                    }
                }
                return true;
            };

            if (!addItems(c["inventory"].toArray(), 0)) {
                m_db.rollback();
                return -1;
            }
        }

        imported++;
    }

    if (!m_db.commit()) {
        qWarning() << "importFromFile failed: commit failed:" << m_db.lastError().text();
        m_db.rollback();
        return -1;
    }

    return imported;
}

QStringList DatabaseManager::creatureSizeNames() const
{
    QStringList names;
    QMetaEnum me = QMetaEnum::fromType<Enums::CreatureSize>();
    for (int i = 0; i < me.keyCount(); ++i)
        names << QString::fromUtf8(me.key(i));
    return names;
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
        qWarning() << "createCharacter failed: " << query.lastError().text();
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

    for (const QString &field : allowed) {
        if (coins.contains(field) && coins.value(field).toInt() < 0) {
            qWarning() << "updateCoins failed:" << field << "cannot be negative";
            return false;
        }
    }

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

int DatabaseManager::createItemDefinition(const QVariantMap &data)
{
    QString name = data.value("name").toString().trimmed();
    if (name.isEmpty()) {
        reportError(QStringLiteral("createItemDefinition failed: name is required"));
        return -1;
    }

    QSqlQuery check(m_db);
    check.prepare("SELECT COUNT(*) FROM item_definitions WHERE name = :name");
    check.bindValue(":name", name);
    if (check.exec() && check.next() && check.value(0).toInt() > 0) {
        reportError(QStringLiteral("createItemDefinition failed: an item named '%1' already exists").arg(name));
        return -1;
    }

    auto optionalText = [&](const QString &key) -> QVariant {
        const QVariant v = data.value(key);
        if (!v.isValid() || v.isNull() || v.toString().isEmpty())
            return QVariant();
        return v;
    };

    auto optionalPositive = [&](const QString &key) -> QVariant {
        if (!data.contains(key)) return QVariant();
        const double d = data.value(key).toDouble();
        return d > 0 ? QVariant(d) : QVariant();
    };

    auto optionalNonNegativeInt = [&](const QString &key) -> QVariant {
        if (!data.contains(key)) return QVariant();
        const int i = data.value(key).toInt();
        return i >= 0 ? QVariant(i) : QVariant();
    };

    const bool isContainer = data.value("is_container", 0).toInt() != 0;

    QSqlQuery insert(m_db);
    insert.prepare(R"(INSERT INTO item_definitions
        (name, item_type, weight_lb, cost, description,
         is_container, container_weight_capacity, fixed_weight,
         rarity, requires_attunement, source)
        VALUES (:name, :item_type, :weight_lb, :cost, :description,
                :is_container, :container_weight_capacity, :fixed_weight,
                :rarity, :requires_attunement, :source))");

    insert.bindValue(":name", name);
    insert.bindValue(":item_type", data.value("item_type").toInt());
    insert.bindValue(":weight_lb", data.value("weight_lb", 0.0).toDouble());
    insert.bindValue(":cost", optionalText("cost"));
    insert.bindValue(":description", optionalText("description"));
    insert.bindValue(":is_container", isContainer ? 1 : 0);
    insert.bindValue(":container_weight_capacity", isContainer ? optionalPositive("container_weight_capacity") : QVariant());
    insert.bindValue(":fixed_weight", isContainer ? optionalPositive("fixed_weight") : QVariant());
    insert.bindValue(":rarity", optionalNonNegativeInt("rarity"));
    insert.bindValue(":requires_attunement", data.value("requires_attunement", 0).toInt() != 0 ? 1 : 0);
    insert.bindValue(":source", static_cast<int>(Enums::ItemSource::Homebrew));

    if (!insert.exec()) {
        reportError(QStringLiteral("createItemDefinition failed: %1").arg(insert.lastError().text()));
        return -1;
    }
    return insert.lastInsertId().toInt();
}

bool DatabaseManager::updateItemDefinition(int id, const QVariantMap &data)
{
    QSqlQuery check(m_db);
    check.prepare("SELECT source FROM item_definitions WHERE id = :id");
    check.bindValue(":id", id);
    if (!check.exec() || !check.next()) {
        reportError(QStringLiteral("updateItemDefinition failed: item %1 not found").arg(id));
        return false;
    }
    if (check.value(0).toInt() != static_cast<int>(Enums::ItemSource::Homebrew)) {
        reportError(QStringLiteral("updateItemDefinition failed: cannot modify SRD items"));
        return false;
    }

    static const QStringList allowed = {
        "name", "item_type", "weight_lb", "cost", "description",
        "is_container", "container_weight_capacity", "fixed_weight",
        "rarity", "requires_attunement"
    };

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
            reportError(QStringLiteral("updateItemDefinition failed: name cannot be empty"));
            return false;
        }
        QSqlQuery nameCheck(m_db);
        nameCheck.prepare("SELECT COUNT(*) FROM item_definitions WHERE name = :name AND id != :id");
        nameCheck.bindValue(":name", trimmedName);
        nameCheck.bindValue(":id", id);
        if (nameCheck.exec() && nameCheck.next() && nameCheck.value(0).toInt() > 0) {
            reportError(QStringLiteral("updateItemDefinition failed: an item named '%1' already exists").arg(trimmedName));
            return false;
        }
    }

    QSqlQuery query(m_db);
    query.prepare("UPDATE item_definitions SET " + assignments.join(", ") + " WHERE id = :id");
    query.bindValue(":id", id);

    for (auto it = data.constBegin(); it != data.constEnd(); ++it) {
        if (!allowed.contains(it.key())) continue;

        if (it.key() == "name") {
            query.bindValue(":name", trimmedName);
        } else if (it.key() == "cost" || it.key() == "description") {
            const QVariant v = it.value();
            if (!v.isValid() || v.isNull() || v.toString().isEmpty())
                query.bindValue(":" + it.key(), QVariant());
            else
                query.bindValue(":" + it.key(), v);
        } else if (it.key() == "container_weight_capacity" || it.key() == "fixed_weight") {
            const double d = it.value().toDouble();
            query.bindValue(":" + it.key(), d > 0 ? QVariant(d) : QVariant());
        } else if (it.key() == "rarity") {
            const int r = it.value().toInt();
            query.bindValue(":" + it.key(), r >= 0 ? QVariant(r) : QVariant());
        } else {
            query.bindValue(":" + it.key(), it.value());
        }
    }

    if (!query.exec()) {
        reportError(QStringLiteral("updateItemDefinition failed: %1").arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool DatabaseManager::deleteItemDefinition(int id)
{
    QSqlQuery check(m_db);
    check.prepare("SELECT source FROM item_definitions WHERE id = :id");
    check.bindValue(":id", id);
    if (!check.exec() || !check.next()) {
        reportError(QStringLiteral("deleteItemDefinition failed: item %1 not found").arg(id));
        return false;
    }
    if (check.value(0).toInt() != static_cast<int>(Enums::ItemSource::Homebrew)) {
        reportError(QStringLiteral("deleteItemDefinition failed: cannot delete SRD items"));
        return false;
    }

    QSqlQuery refCheck(m_db);
    refCheck.prepare("SELECT COUNT(*) FROM inventory_items WHERE item_id = :id");
    refCheck.bindValue(":id", id);
    if (refCheck.exec() && refCheck.next() && refCheck.value(0).toInt() > 0) {
        reportError(QStringLiteral("deleteItemDefinition failed: item is in use; remove from inventories first"));
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare("DELETE FROM item_definitions WHERE id = :id");
    query.bindValue(":id", id);
    if (!query.exec()) {
        reportError(QStringLiteral("deleteItemDefinition failed: %1").arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
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
    if (quantity < 1) {
        reportError(QStringLiteral("addInventoryItem failed: quantity must be at least 1"));
        return -1;
    }

    QSqlQuery defQuery(m_db);
    defQuery.prepare("SELECT COALESCE(fixed_weight, weight_lb), is_container, item_type FROM item_definitions WHERE id = :id");
    defQuery.bindValue(":id", itemId);
    if (!defQuery.exec() || !defQuery.next()) {
        reportError(QStringLiteral("addInventoryItem failed: item definition %1 not found").arg(itemId));
        return -1;
    }
    double itemWeight = defQuery.value(0).toDouble();
    bool isContainerItem = defQuery.value(1).toBool();
    int itemType = defQuery.value(2).toInt();

    if (parentId > 0) {
        if (!isContainer(parentId)) {
            reportError(QStringLiteral("addInventoryItem failed: parent %1 is not a container").arg(parentId));
            return -1;
        }
        if (getItemOwner(parentId) != characterId) {
            reportError(QStringLiteral("addInventoryItem failed: parent %1 belongs to a different character").arg(parentId));
            return -1;
        }
        if (wouldExceedCapacity(parentId, itemWeight * quantity)) {
            reportError(QStringLiteral("Adding this item would exceed the container's weight capacity."));
            return -1;
        }
    }

    bool stackable = !isContainerItem
        && (itemType == static_cast<int>(Enums::ItemType::Gear)
            || itemType == static_cast<int>(Enums::ItemType::Tool));

    if (stackable) {
        QSqlQuery findExisting(m_db);
        findExisting.prepare(R"(SELECT id FROM inventory_items
            WHERE character_id = :characterId
              AND item_id = :itemId
              AND COALESCE(parent_inventory_item_id, 0) = :parentIdOrZero
              AND custom_name IS NULL
              AND notes IS NULL
              AND is_equipped = 0
            LIMIT 1)");
        findExisting.bindValue(":characterId", characterId);
        findExisting.bindValue(":itemId", itemId);
        findExisting.bindValue(":parentIdOrZero", parentId > 0 ? parentId : 0);
        if (findExisting.exec() && findExisting.next()) {
            int existingId = findExisting.value(0).toInt();
            QSqlQuery updateQty(m_db);
            updateQty.prepare("UPDATE inventory_items SET quantity = quantity + :qty WHERE id = :id");
            updateQty.bindValue(":qty", quantity);
            updateQty.bindValue(":id", existingId);
            if (!updateQty.exec()) {
                qWarning() << "addInventoryItem failed: could not stack with existing:" << updateQty.lastError().text();
                return -1;
            }
            return existingId;
        }
    }

    const int rowsToInsert = (!stackable && quantity > 1) ? quantity : 1;
    const int qtyPerRow = (!stackable && quantity > 1) ? 1 : quantity;
    const bool wrap = rowsToInsert > 1;

    if (wrap && !m_db.transaction()) {
        qWarning() << "addInventoryItem failed: could not begin transaction:" << m_db.lastError().text();
        return -1;
    }

    QSqlQuery query(m_db);
    query.prepare(R"(INSERT INTO inventory_items (character_id, item_id, quantity, parent_inventory_item_id) VALUES (:characterId, :itemId, :quantity, :parentId))");
    query.bindValue(":characterId", characterId);
    query.bindValue(":itemId", itemId);
    query.bindValue(":quantity", qtyPerRow);
    query.bindValue(":parentId", parentId > 0 ? parentId : QVariant());

    int lastId = -1;
    for (int i = 0; i < rowsToInsert; ++i) {
        if (!query.exec()) {
            qWarning() << "addInventoryItem failed: " << query.lastError().text();
            if (wrap) m_db.rollback();
            return -1;
        }
        lastId = query.lastInsertId().toInt();
    }

    if (wrap && !m_db.commit()) {
        qWarning() << "addInventoryItem failed: commit failed:" << m_db.lastError().text();
        m_db.rollback();
        return -1;
    }

    return lastId;
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
                    reportError(QStringLiteral("updateInventoryItem failed: parent %1 is not a container").arg(effectiveParent));
                    return false;
                }
                if (getItemOwner(effectiveParent) != getItemOwner(id)) {
                    reportError(QStringLiteral("updateInventoryItem failed: parent %1 belongs to a different character").arg(effectiveParent));
                    return false;
                }
                if (wouldCreateCycle(id, effectiveParent)) {
                    reportError(QStringLiteral("Cannot move container into one of its own contents."));
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
                reportError(QStringLiteral("This change would exceed the container's weight capacity."));
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
    if (!m_db.transaction()) {
        qWarning() << "removeInventoryItem failed: could not begin transaction:" << m_db.lastError().text();
        return false;
    }

    auto body = [&]() -> bool {
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
                    reportError(QStringLiteral("Spilling contents would exceed the parent container's weight capacity."));
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
                reportError(QStringLiteral("Destination %1 is not a container.").arg(destinationContainerId));
                return false;
            }
            if (getItemOwner(destinationContainerId) != getItemOwner(id)) {
                reportError(QStringLiteral("Destination belongs to a different character."));
                return false;
            }
            if (wouldCreateCycle(id, destinationContainerId)) {
                reportError(QStringLiteral("Destination is inside the container being removed."));
                return false;
            }

            double contentsWeight = interiorWeight(id);
            if (wouldExceedCapacity(destinationContainerId, contentsWeight)) {
                reportError(QStringLiteral("Contents would exceed the destination container's weight capacity."));
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
    };

    if (!body()) {
        m_db.rollback();
        return false;
    }
    if (!m_db.commit()) {
        qWarning() << "removeInventoryItem failed: commit failed:" << m_db.lastError().text();
        m_db.rollback();
        return false;
    }
    return true;
}

QVariantList DatabaseManager::getInventoryTree(int characterId)
{
    QVariantList list;
    QSqlQuery query(m_db);

    query.prepare(R"(WITH RECURSIVE tree AS (
        SELECT ii.id, ii.item_id, ii.quantity, ii.parent_inventory_item_id, ii.is_equipped, ii.custom_name, ii.notes, ii.created_at,
            idef.name AS item_name, idef.item_type, idef.weight_lb, idef.is_container, idef.container_weight_capacity, idef.fixed_weight,
            0 AS depth, printf('%020d', ii.id) AS path
        FROM inventory_items ii
        JOIN item_definitions idef ON ii.item_id = idef.id
        WHERE ii.character_id = :characterId AND ii.parent_inventory_item_id IS NULL
        UNION ALL
        SELECT ii.id, ii.item_id, ii.quantity, ii.parent_inventory_item_id, ii.is_equipped, ii.custom_name, ii.notes, ii.created_at,
            idef.name, idef.item_type, idef.weight_lb, idef.is_container, idef.container_weight_capacity, idef.fixed_weight,
            t.depth + 1, t.path || '/' || printf('%020d', ii.id)
        FROM inventory_items ii
        JOIN item_definitions idef ON ii.item_id = idef.id
        JOIN tree t ON ii.parent_inventory_item_id = t.id
    )
    SELECT * FROM tree ORDER BY path)");
    query.bindValue(":characterId", characterId);
    if (!query.exec()) {
        qWarning() << "getInventoryTree failed: " << query.lastError().text();
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