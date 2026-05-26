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
#include <QRegularExpression>
#include <functional>

static QString urlToOpenablePath(const QUrl &url)
{
    const QString local = url.toLocalFile();
    return local.isEmpty() ? url.toString() : local;
}

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

    return writeJsonObject(root, urlToOpenablePath(fileUrl));
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

    return writeJsonObject(root, urlToOpenablePath(fileUrl));
}

int DatabaseManager::importFromFile(const QUrl &fileUrl)
{
    m_lastSkippedCharacters.clear();

    const QString path = urlToOpenablePath(fileUrl);
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

        const QString incomingName = c["name"].toString();
        QSqlQuery sameName(m_db);
        sameName.prepare("SELECT id FROM characters WHERE name = :name");
        sameName.bindValue(":name", incomingName);
        bool alreadyPresent = false;
        if (sameName.exec()) {
            while (sameName.next()) {
                if (buildCharacterJson(sameName.value(0).toInt()) == c) {
                    alreadyPresent = true;
                    break;
                }
            }
        }
        if (alreadyPresent) {
            m_lastSkippedCharacters.append(incomingName);
            continue;
        }

        QVariantMap charData;
        charData["name"] = incomingName;
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

bool DatabaseManager::buildHomebrewPack(const QVariantList &itemIds, QJsonObject &out)
{
    QSqlQuery q(m_db);
    QString sql = QStringLiteral(
        "SELECT id, name, item_type, weight_lb, cost, description, "
        "is_container, container_weight_capacity, fixed_weight, "
        "rarity, requires_attunement "
        "FROM item_definitions WHERE source = :s");

    QStringList idPlaceholders;
    for (int i = 0; i < itemIds.size(); ++i)
        idPlaceholders << QStringLiteral(":id%1").arg(i);
    if (!idPlaceholders.isEmpty())
        sql += QStringLiteral(" AND id IN (%1)").arg(idPlaceholders.join(QLatin1String(", ")));

    sql += QStringLiteral(" ORDER BY name");

    q.prepare(sql);
    q.bindValue(":s", static_cast<int>(Enums::ItemSource::Homebrew));
    for (int i = 0; i < itemIds.size(); ++i)
        q.bindValue(QStringLiteral(":id%1").arg(i), itemIds[i].toInt());
    if (!q.exec()) {
        reportError(QStringLiteral("buildHomebrewPack failed: %1").arg(q.lastError().text()));
        return false;
    }

    auto putOptionalString = [](QJsonObject &obj, const QString &key, const QVariant &v) {
        if (v.isValid() && !v.isNull() && !v.toString().isEmpty())
            obj[key] = v.toString();
    };
    auto putOptionalInt = [](QJsonObject &obj, const QString &key, const QVariant &v) {
        if (v.isValid() && !v.isNull())
            obj[key] = v.toInt();
    };
    auto putOptionalDouble = [](QJsonObject &obj, const QString &key, const QVariant &v) {
        if (v.isValid() && !v.isNull())
            obj[key] = v.toDouble();
    };

    QJsonArray itemsArray;
    while (q.next()) {
        const int id = q.value("id").toInt();
        const int itemType = q.value("item_type").toInt();

        QJsonObject item;
        item["name"] = q.value("name").toString();
        item["item_type"] = itemType;
        item["weight_lb"] = q.value("weight_lb").toDouble();
        putOptionalString(item, "cost", q.value("cost"));
        putOptionalString(item, "description", q.value("description"));
        item["is_container"] = q.value("is_container").toInt();
        putOptionalDouble(item, "container_weight_capacity", q.value("container_weight_capacity"));
        putOptionalDouble(item, "fixed_weight", q.value("fixed_weight"));
        putOptionalInt(item, "rarity", q.value("rarity"));
        item["requires_attunement"] = q.value("requires_attunement").toInt();

        if (itemType == static_cast<int>(Enums::ItemType::Weapon)) {
            const QVariantMap wd = getWeaponDetails(id);
            if (!wd.isEmpty()) {
                QJsonObject wj;
                wj["category"] = wd.value("category").toInt();
                wj["range_type"] = wd.value("range_type").toInt();
                wj["damage_dice"] = wd.value("damage_dice").toString();
                wj["damage_type"] = wd.value("damage_type").toInt();
                wj["properties"] = wd.value("properties").toString();
                putOptionalString(wj, "mastery", wd.value("mastery"));
                putOptionalString(wj, "ammunition_type", wd.value("ammunition_type"));
                item["weapon_details"] = wj;
            }
        } else if (itemType == static_cast<int>(Enums::ItemType::Armor)) {
            const QVariantMap ad = getArmorDetails(id);
            if (!ad.isEmpty()) {
                QJsonObject aj;
                aj["category"] = ad.value("category").toInt();
                aj["ac_base"] = ad.value("ac_base").toInt();
                putOptionalInt(aj, "ac_dex_max", ad.value("ac_dex_max"));
                putOptionalInt(aj, "strength_required", ad.value("strength_required"));
                aj["stealth_disadvantage"] = ad.value("stealth_disadvantage").toInt();
                putOptionalInt(aj, "don_minutes", ad.value("don_minutes"));
                putOptionalInt(aj, "doff_minutes", ad.value("doff_minutes"));
                item["armor_details"] = aj;
            }
        }

        itemsArray.append(item);
    }

    out["items"] = itemsArray;
    return true;
}

bool DatabaseManager::exportHomebrewPack(const QUrl &fileUrl, const QVariantList &itemIds)
{
    QJsonObject root;
    if (!buildHomebrewPack(itemIds, root))
        return false;
    return writeJsonObject(root, urlToOpenablePath(fileUrl));
}

QString DatabaseManager::exportHomebrewPackJson(const QVariantList &itemIds)
{
    QJsonObject root;
    if (!buildHomebrewPack(itemIds, root))
        return QString();
    return QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact));
}

QStringList DatabaseManager::lastSkippedCharacters() const
{
    return m_lastSkippedCharacters;
}

QStringList DatabaseManager::lastSkippedItems() const
{
    return m_lastSkippedItems;
}

int DatabaseManager::importHomebrewPack(const QUrl &fileUrl)
{
    const QString path = urlToOpenablePath(fileUrl);
    if (path.isEmpty()) {
        m_lastSkippedItems.clear();
        reportError(QStringLiteral("importHomebrewPack failed: invalid file path"));
        return -1;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        m_lastSkippedItems.clear();
        reportError(QStringLiteral("importHomebrewPack failed: cannot read %1").arg(path));
        return -1;
    }
    const QByteArray data = file.readAll();
    file.close();
    return importHomebrewPackFromJson(QString::fromUtf8(data));
}

int DatabaseManager::importHomebrewPackFromJson(const QString &json)
{
    m_lastSkippedItems.clear();

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError) {
        reportError(QStringLiteral("importHomebrewPack failed: %1").arg(err.errorString()));
        return -1;
    }
    if (!doc.isObject()) {
        reportError(QStringLiteral("importHomebrewPack failed: root is not a JSON object"));
        return -1;
    }
    const QJsonObject root = doc.object();
    if (!root.contains("items") || !root["items"].isArray()) {
        reportError(QStringLiteral("importHomebrewPack failed: missing 'items' array"));
        return -1;
    }

    if (!m_db.transaction()) {
        reportError(QStringLiteral("importHomebrewPack failed: could not begin transaction"));
        return -1;
    }

    QSqlQuery existsQ(m_db);
    existsQ.prepare("SELECT 1 FROM item_definitions WHERE name = :n");

    int imported = 0;
    const QJsonArray items = root["items"].toArray();
    for (const QJsonValue &iv : items) {
        if (!iv.isObject()) continue;
        const QJsonObject ij = iv.toObject();
        const QString name = ij.value("name").toString().trimmed();
        if (name.isEmpty()) continue;

        existsQ.bindValue(":n", name);
        if (!existsQ.exec()) {
            reportError(QStringLiteral("importHomebrewPack failed: %1").arg(existsQ.lastError().text()));
            m_db.rollback();
            return -1;
        }
        if (existsQ.next()) {
            m_lastSkippedItems << name;
            existsQ.finish();
            continue;
        }
        existsQ.finish();

        QVariantMap itemData;
        itemData["name"] = name;
        itemData["item_type"] = ij.value("item_type").toInt();
        itemData["weight_lb"] = ij.value("weight_lb").toDouble();
        if (ij.contains("cost"))        itemData["cost"]        = ij.value("cost").toString();
        if (ij.contains("description")) itemData["description"] = ij.value("description").toString();
        itemData["is_container"] = ij.value("is_container").toInt();
        if (ij.contains("container_weight_capacity"))
            itemData["container_weight_capacity"] = ij.value("container_weight_capacity").toDouble();
        if (ij.contains("fixed_weight"))
            itemData["fixed_weight"] = ij.value("fixed_weight").toDouble();
        if (ij.contains("rarity"))
            itemData["rarity"] = ij.value("rarity").toInt();
        itemData["requires_attunement"] = ij.value("requires_attunement").toInt();

        const int newId = createItemDefinition(itemData);
        if (newId < 0) {
            m_db.rollback();
            return -1;
        }

        const int itemType = itemData.value("item_type").toInt();
        if (itemType == static_cast<int>(Enums::ItemType::Weapon) && ij.contains("weapon_details")) {
            const QJsonObject wj = ij.value("weapon_details").toObject();
            QVariantMap wd;
            wd["category"]    = wj.value("category").toInt();
            wd["range_type"]  = wj.value("range_type").toInt();
            wd["damage_dice"] = wj.value("damage_dice").toString();
            wd["damage_type"] = wj.value("damage_type").toInt();
            wd["properties"]  = wj.value("properties").toString("[]");
            if (wj.contains("mastery"))         wd["mastery"]         = wj.value("mastery").toString();
            if (wj.contains("ammunition_type")) wd["ammunition_type"] = wj.value("ammunition_type").toString();
            if (!setWeaponDetails(newId, wd)) {
                m_db.rollback();
                return -1;
            }
        } else if (itemType == static_cast<int>(Enums::ItemType::Armor) && ij.contains("armor_details")) {
            const QJsonObject aj = ij.value("armor_details").toObject();
            QVariantMap ad;
            ad["category"] = aj.value("category").toInt();
            ad["ac_base"]  = aj.value("ac_base").toInt();
            if (aj.contains("ac_dex_max"))         ad["ac_dex_max"]         = aj.value("ac_dex_max").toInt();
            if (aj.contains("strength_required"))  ad["strength_required"]  = aj.value("strength_required").toInt();
            ad["stealth_disadvantage"] = aj.value("stealth_disadvantage").toInt();
            if (aj.contains("don_minutes"))   ad["don_minutes"]   = aj.value("don_minutes").toInt();
            if (aj.contains("doff_minutes"))  ad["doff_minutes"]  = aj.value("doff_minutes").toInt();
            if (!setArmorDetails(newId, ad)) {
                m_db.rollback();
                return -1;
            }
        }

        ++imported;
    }

    if (!m_db.commit()) {
        reportError(QStringLiteral("importHomebrewPack failed: commit failed: %1").arg(m_db.lastError().text()));
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

int DatabaseManager::saveItemDefinition(int id, const QVariantMap &itemData,
                                         const QVariantMap &weaponData,
                                         const QVariantMap &armorData)
{
    if (!m_db.transaction()) {
        reportError(QStringLiteral("saveItemDefinition failed: could not begin transaction: %1").arg(m_db.lastError().text()));
        return -1;
    }

    auto body = [&]() -> int {
        int savedId = id;

        if (id <= 0) {
            savedId = createItemDefinition(itemData);
            if (savedId < 0) return -1;
        } else {
            if (!updateItemDefinition(id, itemData)) return -1;
        }

        const int itemType = itemData.value("item_type", -1).toInt();
        const int weaponT = static_cast<int>(Enums::ItemType::Weapon);
        const int armorT  = static_cast<int>(Enums::ItemType::Armor);

        if (itemType == weaponT) {
            if (!setWeaponDetails(savedId, weaponData)) return -1;
        } else if (itemType == armorT) {
            if (!setArmorDetails(savedId, armorData)) return -1;
        }
        if (id > 0) {
            if (itemType != weaponT && !clearWeaponDetails(savedId)) return -1;
            if (itemType != armorT  && !clearArmorDetails(savedId))  return -1;
        }
        return savedId;
    };

    const int result = body();
    if (result < 0) {
        m_db.rollback();
        return -1;
    }
    if (!m_db.commit()) {
        reportError(QStringLiteral("saveItemDefinition failed: commit failed: %1").arg(m_db.lastError().text()));
        m_db.rollback();
        return -1;
    }
    return result;
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

bool DatabaseManager::setWeaponDetails(int itemId, const QVariantMap &data)
{
    QSqlQuery check(m_db);
    check.prepare("SELECT item_type, source FROM item_definitions WHERE id = :id");
    check.bindValue(":id", itemId);
    if (!check.exec() || !check.next()) {
        reportError(QStringLiteral("setWeaponDetails failed: item %1 not found").arg(itemId));
        return false;
    }
    if (check.value(0).toInt() != static_cast<int>(Enums::ItemType::Weapon)) {
        reportError(QStringLiteral("setWeaponDetails failed: item %1 is not a weapon").arg(itemId));
        return false;
    }
    if (check.value(1).toInt() != static_cast<int>(Enums::ItemSource::Homebrew)) {
        reportError(QStringLiteral("setWeaponDetails failed: cannot modify SRD items"));
        return false;
    }

    const QString damageDice = data.value("damage_dice").toString().trimmed();
    if (damageDice.isEmpty()) {
        reportError(QStringLiteral("setWeaponDetails failed: damage_dice is required"));
        return false;
    }
    static const QRegularExpression diceRegex(QStringLiteral("^[1-9]\\d*(d[1-9]\\d*)?$"));
    if (!diceRegex.match(damageDice).hasMatch()) {
        reportError(QStringLiteral("setWeaponDetails failed: damage_dice '%1' must be N or NdS with positive values (e.g. 1, 1d8, 2d6)").arg(damageDice));
        return false;
    }

    auto optionalText = [&](const QString &key) -> QVariant {
        const QVariant v = data.value(key);
        if (!v.isValid() || v.isNull() || v.toString().isEmpty())
            return QVariant();
        return v.toString();
    };

    QSqlQuery q(m_db);
    q.prepare(R"(INSERT INTO weapon_details
        (item_id, category, range_type, damage_dice, damage_type, properties, mastery, ammunition_type)
        VALUES (:item_id, :category, :range_type, :damage_dice, :damage_type, :properties, :mastery, :ammunition_type)
        ON CONFLICT(item_id) DO UPDATE SET
            category = excluded.category,
            range_type = excluded.range_type,
            damage_dice = excluded.damage_dice,
            damage_type = excluded.damage_type,
            properties = excluded.properties,
            mastery = excluded.mastery,
            ammunition_type = excluded.ammunition_type)");
    q.bindValue(":item_id", itemId);
    q.bindValue(":category", data.value("category").toInt());
    q.bindValue(":range_type", data.value("range_type").toInt());
    q.bindValue(":damage_dice", damageDice);
    q.bindValue(":damage_type", data.value("damage_type").toInt());
    q.bindValue(":properties", data.value("properties", "[]").toString());
    q.bindValue(":mastery", optionalText("mastery"));
    q.bindValue(":ammunition_type", optionalText("ammunition_type"));

    if (!q.exec()) {
        reportError(QStringLiteral("setWeaponDetails failed: %1").arg(q.lastError().text()));
        return false;
    }
    return true;
}

bool DatabaseManager::clearWeaponDetails(int itemId)
{
    QSqlQuery check(m_db);
    check.prepare("SELECT source FROM item_definitions WHERE id = :id");
    check.bindValue(":id", itemId);
    if (!check.exec() || !check.next())
        return false;
    if (check.value(0).toInt() != static_cast<int>(Enums::ItemSource::Homebrew)) {
        reportError(QStringLiteral("clearWeaponDetails failed: cannot modify SRD items"));
        return false;
    }

    QSqlQuery q(m_db);
    q.prepare("DELETE FROM weapon_details WHERE item_id = :id");
    q.bindValue(":id", itemId);
    if (!q.exec()) {
        reportError(QStringLiteral("clearWeaponDetails failed: %1").arg(q.lastError().text()));
        return false;
    }
    return true;
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

bool DatabaseManager::setArmorDetails(int itemId, const QVariantMap &data)
{
    QSqlQuery check(m_db);
    check.prepare("SELECT item_type, source FROM item_definitions WHERE id = :id");
    check.bindValue(":id", itemId);
    if (!check.exec() || !check.next()) {
        reportError(QStringLiteral("setArmorDetails failed: item %1 not found").arg(itemId));
        return false;
    }
    if (check.value(0).toInt() != static_cast<int>(Enums::ItemType::Armor)) {
        reportError(QStringLiteral("setArmorDetails failed: item %1 is not armor").arg(itemId));
        return false;
    }
    if (check.value(1).toInt() != static_cast<int>(Enums::ItemSource::Homebrew)) {
        reportError(QStringLiteral("setArmorDetails failed: cannot modify SRD items"));
        return false;
    }

    bool ok = false;
    const int acBase = data.value("ac_base").toInt(&ok);
    if (!ok || acBase < 1) {
        reportError(QStringLiteral("setArmorDetails failed: ac_base is required and must be >= 1"));
        return false;
    }

    auto optionalInt = [&](const QString &key) -> QVariant {
        const QVariant v = data.value(key);
        if (!v.isValid() || v.isNull()) return QVariant();
        bool parseOk = false;
        const int n = v.toInt(&parseOk);
        if (!parseOk) return QVariant();
        return n;
    };

    QSqlQuery q(m_db);
    q.prepare(R"(INSERT INTO armor_details
        (item_id, category, ac_base, ac_dex_max, strength_required, stealth_disadvantage, don_minutes, doff_minutes)
        VALUES (:item_id, :category, :ac_base, :ac_dex_max, :strength_required, :stealth_disadvantage, :don_minutes, :doff_minutes)
        ON CONFLICT(item_id) DO UPDATE SET
            category = excluded.category,
            ac_base = excluded.ac_base,
            ac_dex_max = excluded.ac_dex_max,
            strength_required = excluded.strength_required,
            stealth_disadvantage = excluded.stealth_disadvantage,
            don_minutes = excluded.don_minutes,
            doff_minutes = excluded.doff_minutes)");
    q.bindValue(":item_id", itemId);
    q.bindValue(":category", data.value("category").toInt());
    q.bindValue(":ac_base", acBase);
    q.bindValue(":ac_dex_max", optionalInt("ac_dex_max"));
    q.bindValue(":strength_required", optionalInt("strength_required"));
    q.bindValue(":stealth_disadvantage", data.value("stealth_disadvantage").toInt() ? 1 : 0);
    q.bindValue(":don_minutes", optionalInt("don_minutes"));
    q.bindValue(":doff_minutes", optionalInt("doff_minutes"));

    if (!q.exec()) {
        reportError(QStringLiteral("setArmorDetails failed: %1").arg(q.lastError().text()));
        return false;
    }
    return true;
}

bool DatabaseManager::clearArmorDetails(int itemId)
{
    QSqlQuery check(m_db);
    check.prepare("SELECT source FROM item_definitions WHERE id = :id");
    check.bindValue(":id", itemId);
    if (!check.exec() || !check.next())
        return false;
    if (check.value(0).toInt() != static_cast<int>(Enums::ItemSource::Homebrew)) {
        reportError(QStringLiteral("clearArmorDetails failed: cannot modify SRD items"));
        return false;
    }

    QSqlQuery q(m_db);
    q.prepare("DELETE FROM armor_details WHERE item_id = :id");
    q.bindValue(":id", itemId);
    if (!q.exec()) {
        reportError(QStringLiteral("clearArmorDetails failed: %1").arg(q.lastError().text()));
        return false;
    }
    return true;
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
            idef.source AS item_source, idef.description AS item_description, idef.cost AS item_cost,
            0 AS depth, printf('%020d', ii.id) AS path
        FROM inventory_items ii
        JOIN item_definitions idef ON ii.item_id = idef.id
        WHERE ii.character_id = :characterId AND ii.parent_inventory_item_id IS NULL
        UNION ALL
        SELECT ii.id, ii.item_id, ii.quantity, ii.parent_inventory_item_id, ii.is_equipped, ii.custom_name, ii.notes, ii.created_at,
            idef.name, idef.item_type, idef.weight_lb, idef.is_container, idef.container_weight_capacity, idef.fixed_weight,
            idef.source, idef.description, idef.cost,
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

QJsonObject DatabaseManager::buildInventoryItemShareNode(int inventoryItemId, int overrideQuantity)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT ii.item_id, ii.quantity, ii.custom_name, ii.notes, ii.is_equipped, "
              "idef.name, idef.item_type, idef.weight_lb, idef.cost, idef.description, "
              "idef.is_container, idef.container_weight_capacity, idef.fixed_weight, "
              "idef.rarity, idef.requires_attunement "
              "FROM inventory_items ii "
              "JOIN item_definitions idef ON ii.item_id = idef.id "
              "WHERE ii.id = :id");
    q.bindValue(":id", inventoryItemId);
    if (!q.exec() || !q.next())
        return QJsonObject();

    const int itemId = q.value("item_id").toInt();
    const int itemType = q.value("item_type").toInt();
    const int isContainer = q.value("is_container").toInt();
    const int rowQty = q.value("quantity").toInt();
    const int sharedQty = overrideQuantity > 0 ? overrideQuantity : rowQty;

    QJsonObject def;
    def["name"] = q.value("name").toString();
    def["item_type"] = itemType;
    def["weight_lb"] = q.value("weight_lb").toDouble();
    const QString cost = q.value("cost").toString();
    if (!cost.isEmpty()) def["cost"] = cost;
    const QString description = q.value("description").toString();
    if (!description.isEmpty()) def["description"] = description;
    def["is_container"] = isContainer;
    if (!q.value("container_weight_capacity").isNull())
        def["container_weight_capacity"] = q.value("container_weight_capacity").toDouble();
    if (!q.value("fixed_weight").isNull())
        def["fixed_weight"] = q.value("fixed_weight").toDouble();
    if (!q.value("rarity").isNull())
        def["rarity"] = q.value("rarity").toInt();
    def["requires_attunement"] = q.value("requires_attunement").toInt();

    if (itemType == static_cast<int>(Enums::ItemType::Weapon)) {
        const QVariantMap wd = getWeaponDetails(itemId);
        if (!wd.isEmpty()) {
            QJsonObject wj;
            wj["category"]    = wd.value("category").toInt();
            wj["range_type"]  = wd.value("range_type").toInt();
            wj["damage_dice"] = wd.value("damage_dice").toString();
            wj["damage_type"] = wd.value("damage_type").toInt();
            wj["properties"]  = wd.value("properties").toString();
            const QString mastery = wd.value("mastery").toString();
            if (!mastery.isEmpty()) wj["mastery"] = mastery;
            const QString ammo = wd.value("ammunition_type").toString();
            if (!ammo.isEmpty()) wj["ammunition_type"] = ammo;
            def["weapon_details"] = wj;
        }
    } else if (itemType == static_cast<int>(Enums::ItemType::Armor)) {
        const QVariantMap ad = getArmorDetails(itemId);
        if (!ad.isEmpty()) {
            QJsonObject aj;
            aj["category"] = ad.value("category").toInt();
            aj["ac_base"]  = ad.value("ac_base").toInt();
            if (!ad.value("ac_dex_max").isNull())
                aj["ac_dex_max"] = ad.value("ac_dex_max").toInt();
            if (!ad.value("strength_required").isNull())
                aj["strength_required"] = ad.value("strength_required").toInt();
            aj["stealth_disadvantage"] = ad.value("stealth_disadvantage").toInt();
            if (!ad.value("don_minutes").isNull())
                aj["don_minutes"] = ad.value("don_minutes").toInt();
            if (!ad.value("doff_minutes").isNull())
                aj["doff_minutes"] = ad.value("doff_minutes").toInt();
            def["armor_details"] = aj;
        }
    }

    QJsonObject instance;
    instance["quantity"] = sharedQty;
    const QString customName = q.value("custom_name").toString();
    if (!customName.isEmpty()) instance["custom_name"] = customName;
    const QString notes = q.value("notes").toString();
    if (!notes.isEmpty()) instance["notes"] = notes;
    instance["is_equipped"] = q.value("is_equipped").toInt();

    QJsonArray children;
    if (isContainer) {
        const QVariantList contents = getContainerContents(inventoryItemId);
        for (const QVariant &c : contents) {
            const int childId = c.toMap().value("id").toInt();
            const QJsonObject childNode = buildInventoryItemShareNode(childId);
            if (!childNode.isEmpty())
                children.append(childNode);
        }
    }

    QJsonObject node;
    node["definition"] = def;
    node["instance"] = instance;
    if (!children.isEmpty())
        node["children"] = children;
    return node;
}

QString DatabaseManager::buildInventoryItemShareJson(int inventoryItemId, int quantity)
{
    const QJsonObject node = buildInventoryItemShareNode(inventoryItemId, quantity);
    if (node.isEmpty()) {
        reportError(QStringLiteral("buildInventoryItemShareJson: item %1 not found").arg(inventoryItemId));
        return QString();
    }
    QJsonObject envelope;
    envelope["kind"] = "inventory_item_share";
    envelope["v"] = 1;
    envelope["root"] = node;
    return QString::fromUtf8(QJsonDocument(envelope).toJson(QJsonDocument::Compact));
}

int DatabaseManager::importInventoryItemNode(const QJsonObject &node, int characterId, int parentId)
{
    const QJsonObject def = node.value("definition").toObject();
    const QJsonObject instance = node.value("instance").toObject();
    const QString defName = def.value("name").toString().trimmed();
    if (defName.isEmpty()) {
        reportError("importInventoryItemNode: definition missing name");
        return -1;
    }

    QSqlQuery lookup(m_db);
    lookup.prepare("SELECT id FROM item_definitions WHERE name = :n");
    lookup.bindValue(":n", defName);
    if (!lookup.exec()) {
        reportError(QStringLiteral("importInventoryItemNode: %1").arg(lookup.lastError().text()));
        return -1;
    }

    int defId = -1;
    if (lookup.next()) {
        defId = lookup.value(0).toInt();
    } else {
        QVariantMap itemData;
        itemData["name"] = defName;
        itemData["item_type"] = def.value("item_type").toInt();
        itemData["weight_lb"] = def.value("weight_lb").toDouble();
        if (def.contains("cost"))        itemData["cost"]        = def.value("cost").toString();
        if (def.contains("description")) itemData["description"] = def.value("description").toString();
        itemData["is_container"] = def.value("is_container").toInt();
        if (def.contains("container_weight_capacity"))
            itemData["container_weight_capacity"] = def.value("container_weight_capacity").toDouble();
        if (def.contains("fixed_weight"))
            itemData["fixed_weight"] = def.value("fixed_weight").toDouble();
        if (def.contains("rarity"))
            itemData["rarity"] = def.value("rarity").toInt();
        itemData["requires_attunement"] = def.value("requires_attunement").toInt();

        defId = createItemDefinition(itemData);
        if (defId < 0)
            return -1;

        const int itemType = itemData.value("item_type").toInt();
        if (itemType == static_cast<int>(Enums::ItemType::Weapon) && def.contains("weapon_details")) {
            const QJsonObject wj = def.value("weapon_details").toObject();
            QVariantMap wd;
            wd["category"]    = wj.value("category").toInt();
            wd["range_type"]  = wj.value("range_type").toInt();
            wd["damage_dice"] = wj.value("damage_dice").toString();
            wd["damage_type"] = wj.value("damage_type").toInt();
            wd["properties"]  = wj.value("properties").toString("[]");
            if (wj.contains("mastery"))         wd["mastery"]         = wj.value("mastery").toString();
            if (wj.contains("ammunition_type")) wd["ammunition_type"] = wj.value("ammunition_type").toString();
            if (!setWeaponDetails(defId, wd))
                return -1;
        } else if (itemType == static_cast<int>(Enums::ItemType::Armor) && def.contains("armor_details")) {
            const QJsonObject aj = def.value("armor_details").toObject();
            QVariantMap ad;
            ad["category"] = aj.value("category").toInt();
            ad["ac_base"]  = aj.value("ac_base").toInt();
            if (aj.contains("ac_dex_max"))         ad["ac_dex_max"]         = aj.value("ac_dex_max").toInt();
            if (aj.contains("strength_required"))  ad["strength_required"]  = aj.value("strength_required").toInt();
            ad["stealth_disadvantage"] = aj.value("stealth_disadvantage").toInt();
            if (aj.contains("don_minutes"))   ad["don_minutes"]   = aj.value("don_minutes").toInt();
            if (aj.contains("doff_minutes"))  ad["doff_minutes"]  = aj.value("doff_minutes").toInt();
            if (!setArmorDetails(defId, ad))
                return -1;
        }
    }

    const int qty = std::max(1, instance.value("quantity").toInt(1));
    const int newInvItemId = addInventoryItem(characterId, defId, qty, parentId);
    if (newInvItemId < 0)
        return -1;

    if (node.contains("children")) {
        const QJsonArray children = node.value("children").toArray();
        for (const QJsonValue &cv : children) {
            if (!cv.isObject()) continue;
            if (importInventoryItemNode(cv.toObject(), characterId, newInvItemId) < 0)
                return -1;
        }
    }

    return newInvItemId;
}

int DatabaseManager::importInventoryItemFromShare(const QString &payloadJson, int characterId)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(payloadJson.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        reportError(QStringLiteral("importInventoryItemFromShare: invalid JSON: %1").arg(err.errorString()));
        return -1;
    }
    const QJsonObject envelope = doc.object();
    if (envelope.value("kind").toString() != QLatin1String("inventory_item_share")) {
        reportError("importInventoryItemFromShare: wrong kind");
        return -1;
    }
    const QJsonObject root = envelope.value("root").toObject();
    if (root.isEmpty()) {
        reportError("importInventoryItemFromShare: empty root");
        return -1;
    }

    if (!m_db.transaction()) {
        reportError("importInventoryItemFromShare: could not begin transaction");
        return -1;
    }

    const int rootId = importInventoryItemNode(root, characterId, -1);
    if (rootId < 0) {
        m_db.rollback();
        return -1;
    }

    if (!m_db.commit()) {
        reportError(QStringLiteral("importInventoryItemFromShare: commit failed: %1").arg(m_db.lastError().text()));
        m_db.rollback();
        return -1;
    }
    return rootId;
}

bool DatabaseManager::commitOutgoingShare(int inventoryItemId, int sharedQuantity)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT ii.quantity, idef.is_container "
              "FROM inventory_items ii "
              "JOIN item_definitions idef ON ii.item_id = idef.id "
              "WHERE ii.id = :id");
    q.bindValue(":id", inventoryItemId);
    if (!q.exec() || !q.next()) {
        reportError(QStringLiteral("commitOutgoingShare: item %1 not found").arg(inventoryItemId));
        return false;
    }
    const int currentQty = q.value(0).toInt();
    const bool isContainerRow = q.value(1).toInt() == 1;

    if (isContainerRow || sharedQuantity >= currentQty) {
        const Enums::RemovalMode mode = isContainerRow
            ? Enums::RemovalMode::DeleteAll
            : Enums::RemovalMode::SpillToParent;
        return removeInventoryItem(inventoryItemId, mode);
    }
    QVariantMap data;
    data["quantity"] = currentQty - sharedQuantity;
    return updateInventoryItem(inventoryItemId, data);
}

bool DatabaseManager::itemDefinitionExistsByName(const QString &name)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT 1 FROM item_definitions WHERE name = :n LIMIT 1");
    q.bindValue(":n", name.trimmed());
    return q.exec() && q.next();
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