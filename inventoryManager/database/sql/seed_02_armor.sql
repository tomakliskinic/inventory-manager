-- ==============================
-- LIGHT ARMOR
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, source) VALUES
    ('Padded Armor',          1, 8.0,  '5 GP',  0),
    ('Leather Armor',         1, 10.0, '10 GP', 0),
    ('Studded Leather Armor', 1, 13.0, '45 GP', 0);

INSERT INTO armor_details (item_id, category, ac_base, ac_dex_max, strength_required, stealth_disadvantage, don_minutes, doff_minutes) VALUES
    ((SELECT id FROM item_definitions WHERE name='Padded Armor'),          0, 11, NULL, NULL, 1, 1, 1),
    ((SELECT id FROM item_definitions WHERE name='Leather Armor'),         0, 11, NULL, NULL, 0, 1, 1),
    ((SELECT id FROM item_definitions WHERE name='Studded Leather Armor'), 0, 12, NULL, NULL, 0, 1, 1);

-- ==============================
-- MEDIUM ARMOR
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, source) VALUES
    ('Hide Armor',       1, 12.0, '10 GP',  0),
    ('Chain Shirt',      1, 20.0, '50 GP',  0),
    ('Scale Mail',       1, 45.0, '50 GP',  0),
    ('Breastplate',      1, 20.0, '400 GP', 0),
    ('Half Plate Armor', 1, 40.0, '750 GP', 0);

INSERT INTO armor_details (item_id, category, ac_base, ac_dex_max, strength_required, stealth_disadvantage, don_minutes, doff_minutes) VALUES
    ((SELECT id FROM item_definitions WHERE name='Hide Armor'),       1, 12, 2, NULL, 0, 5, 1),
    ((SELECT id FROM item_definitions WHERE name='Chain Shirt'),      1, 13, 2, NULL, 0, 5, 1),
    ((SELECT id FROM item_definitions WHERE name='Scale Mail'),       1, 14, 2, NULL, 1, 5, 1),
    ((SELECT id FROM item_definitions WHERE name='Breastplate'),      1, 14, 2, NULL, 0, 5, 1),
    ((SELECT id FROM item_definitions WHERE name='Half Plate Armor'), 1, 15, 2, NULL, 1, 5, 1);

-- ==============================
-- HEAVY ARMOR
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, source) VALUES
    ('Ring Mail',    1, 40.0, '30 GP',    0),
    ('Chain Mail',   1, 55.0, '75 GP',    0),
    ('Splint Armor', 1, 60.0, '200 GP',   0),
    ('Plate Armor',  1, 65.0, '1,500 GP', 0);

INSERT INTO armor_details (item_id, category, ac_base, ac_dex_max, strength_required, stealth_disadvantage, don_minutes, doff_minutes) VALUES
    ((SELECT id FROM item_definitions WHERE name='Ring Mail'),    2, 14, 0, NULL, 1, 10, 5),
    ((SELECT id FROM item_definitions WHERE name='Chain Mail'),   2, 16, 0, 13,   1, 10, 5),
    ((SELECT id FROM item_definitions WHERE name='Splint Armor'), 2, 17, 0, 15,   1, 10, 5),
    ((SELECT id FROM item_definitions WHERE name='Plate Armor'),  2, 18, 0, 15,   1, 10, 5);

-- ==============================
-- SHIELD
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, source) VALUES
    ('Shield', 1, 6.0, '10 GP', 0);

INSERT INTO armor_details (item_id, category, ac_base, ac_dex_max, strength_required, stealth_disadvantage, don_minutes, doff_minutes) VALUES
    ((SELECT id FROM item_definitions WHERE name='Shield'), 3, 2, NULL, NULL, 0, NULL, NULL);