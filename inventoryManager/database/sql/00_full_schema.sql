CREATE TABLE IF NOT EXISTS characters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    level INTEGER NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 20),
    strength INTEGER NOT NULL DEFAULT 10 CHECK (strength BETWEEN 1 AND 30),
    size INTEGER NOT NULL DEFAULT 2,
    race TEXT,
    class TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS character_coins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    character_id INTEGER NOT NULL UNIQUE,
    cp INTEGER NOT NULL DEFAULT 0 CHECK (cp >= 0),
    sp INTEGER NOT NULL DEFAULT 0 CHECK (sp >= 0),
    ep INTEGER NOT NULL DEFAULT 0 CHECK (ep >= 0),
    gp INTEGER NOT NULL DEFAULT 0 CHECK (gp >= 0),
    pp INTEGER NOT NULL DEFAULT 0 CHECK (pp >= 0),

    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS item_definitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    item_type INTEGER NOT NULL,
    weight_lb REAL NOT NULL DEFAULT 0.0 CHECK (weight_lb >= 0),
    cost TEXT,
    description TEXT,

    is_container INTEGER NOT NULL DEFAULT 0 CHECK (is_container IN (0, 1)),
    container_weight_capacity REAL CHECK (container_weight_capacity > 0),
    container_volume_capacity REAL CHECK (container_volume_capacity > 0),
    fixed_weight REAL CHECK (fixed_weight >= 0),

    rarity INTEGER,
    requires_attunement INTEGER NOT NULL DEFAULT 0 CHECK (requires_attunement IN (0, 1)),

    source INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS weapon_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL UNIQUE,
    category INTEGER NOT NULL,
    range_type INTEGER NOT NULL,
    damage_dice TEXT NOT NULL,
    damage_type INTEGER NOT NULL,
    properties TEXT NOT NULL DEFAULT '[]',
    mastery TEXT,
    ammunition_type TEXT,

    FOREIGN KEY (item_id) REFERENCES item_definitions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS armor_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL UNIQUE,
    category INTEGER NOT NULL,
    ac_base INTEGER NOT NULL,
    ac_dex_max INTEGER,
    strength_required INTEGER,
    stealth_disadvantage INTEGER NOT NULL DEFAULT 0 CHECK (stealth_disadvantage IN (0, 1)),
    don_minutes INTEGER,
    doff_minutes INTEGER,

    FOREIGN KEY (item_id) REFERENCES item_definitions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS inventory_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    character_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 1),
    parent_inventory_item_id INTEGER,
    is_equipped INTEGER NOT NULL DEFAULT 0 CHECK (is_equipped IN (0, 1)),
    custom_name TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES item_definitions(id) ON DELETE RESTRICT,
    FOREIGN KEY (parent_inventory_item_id) REFERENCES inventory_items(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_inventory_character
    ON inventory_items(character_id);

CREATE INDEX IF NOT EXISTS idx_inventory_parent
    ON inventory_items(parent_inventory_item_id);

CREATE TRIGGER IF NOT EXISTS trg_characters_updated
    AFTER UPDATE ON characters
    FOR EACH ROW
BEGIN
    UPDATE characters SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_inventory_updated
    AFTER UPDATE ON inventory_items
    FOR EACH ROW
BEGIN
    UPDATE inventory_items SET updated_at = datetime('now') WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_create_coins_for_character
    AFTER INSERT ON characters
    FOR EACH ROW
BEGIN
    INSERT INTO character_coins (character_id) VALUES (NEW.id);
END;