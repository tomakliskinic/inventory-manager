-- ==============================
-- SIMPLE MELEE WEAPONS
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, source) VALUES
    ('Club',         0, 2.0,   '1 SP',  0),
    ('Dagger',       0, 1.0,   '2 GP',  0),
    ('Greatclub',    0, 10.0,  '2 SP',  0),
    ('Handaxe',      0, 2.0,   '5 GP',  0),
    ('Javelin',      0, 2.0,   '5 SP',  0),
    ('Light Hammer', 0, 2.0,   '2 GP',  0),
    ('Mace',         0, 4.0,   '5 GP',  0),
    ('Quarterstaff', 0, 4.0,   '2 SP',  0),
    ('Sickle',       0, 2.0,   '1 GP',  0),
    ('Spear',        0, 3.0,   '1 GP',  0);

INSERT INTO weapon_details (item_id, category, range_type, damage_dice, damage_type, properties, mastery) VALUES
    ((SELECT id FROM item_definitions WHERE name='Club'),         0, 0, '1d4', 0, '["Light"]',                                  'Slow'),
    ((SELECT id FROM item_definitions WHERE name='Dagger'),       0, 0, '1d4', 1, '["Finesse","Light","Thrown (Range 20/60)"]', 'Nick'),
    ((SELECT id FROM item_definitions WHERE name='Greatclub'),    0, 0, '1d8', 0, '["Two-Handed"]',                             'Push'),
    ((SELECT id FROM item_definitions WHERE name='Handaxe'),      0, 0, '1d6', 2, '["Light","Thrown (Range 20/60)"]',           'Vex'),
    ((SELECT id FROM item_definitions WHERE name='Javelin'),      0, 0, '1d6', 1, '["Thrown (Range 30/120)"]',                  'Slow'),
    ((SELECT id FROM item_definitions WHERE name='Light Hammer'), 0, 0, '1d4', 0, '["Light","Thrown (Range 20/60)"]',           'Nick'),
    ((SELECT id FROM item_definitions WHERE name='Mace'),         0, 0, '1d6', 0, '[]',                                         'Sap'),
    ((SELECT id FROM item_definitions WHERE name='Quarterstaff'), 0, 0, '1d6', 0, '["Versatile (1d8)"]',                        'Topple'),
    ((SELECT id FROM item_definitions WHERE name='Sickle'),       0, 0, '1d4', 2, '["Light"]',                                  'Nick'),
    ((SELECT id FROM item_definitions WHERE name='Spear'),        0, 0, '1d6', 1, '["Thrown (Range 20/60)","Versatile (1d8)"]', 'Sap');

-- ==============================
-- SIMPLE RANGED WEAPONS
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, source) VALUES
    ('Dart',           0, 0.25,  '5 CP',  0),
    ('Light Crossbow', 0, 5.0,   '25 GP', 0),
    ('Shortbow',       0, 2.0,   '25 GP', 0),
    ('Sling',          0, 0.0,   '1 SP',  0);

INSERT INTO weapon_details (item_id, category, range_type, damage_dice, damage_type, properties, mastery, ammunition_type) VALUES
    ((SELECT id FROM item_definitions WHERE name='Dart'),           0, 1, '1d4', 1, '["Finesse","Thrown (Range 20/60)"]',                          'Vex',  NULL),
    ((SELECT id FROM item_definitions WHERE name='Light Crossbow'), 0, 1, '1d8', 1, '["Ammunition (Range 80/320)","Loading","Two-Handed"]',        'Slow', 'Bolt'),
    ((SELECT id FROM item_definitions WHERE name='Shortbow'),       0, 1, '1d6', 1, '["Ammunition (Range 80/320)","Two-Handed"]',                  'Vex',  'Arrow'),
    ((SELECT id FROM item_definitions WHERE name='Sling'),          0, 1, '1d4', 0, '["Ammunition (Range 30/120)"]',                               'Slow', 'Bullet');

-- ==============================
-- MARTIAL MELEE WEAPONS
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, source) VALUES
    ('Battleaxe',   0, 4.0,   '10 GP', 0),
    ('Flail',       0, 2.0,   '10 GP', 0),
    ('Glaive',      0, 6.0,   '20 GP', 0),
    ('Greataxe',    0, 7.0,   '30 GP', 0),
    ('Greatsword',  0, 6.0,   '50 GP', 0),
    ('Halberd',     0, 6.0,   '20 GP', 0),
    ('Lance',       0, 6.0,   '10 GP', 0),
    ('Longsword',   0, 3.0,   '15 GP', 0),
    ('Maul',        0, 10.0,  '10 GP', 0),
    ('Morningstar', 0, 4.0,   '15 GP', 0),
    ('Pike',        0, 18.0,  '5 GP',  0),
    ('Rapier',      0, 2.0,   '25 GP', 0),
    ('Scimitar',    0, 3.0,   '25 GP', 0),
    ('Shortsword',  0, 2.0,   '10 GP', 0),
    ('Trident',     0, 4.0,   '5 GP',  0),
    ('Warhammer',   0, 5.0,   '15 GP', 0),
    ('War Pick',    0, 2.0,   '5 GP',  0),
    ('Whip',        0, 3.0,   '2 GP',  0);

INSERT INTO weapon_details (item_id, category, range_type, damage_dice, damage_type, properties, mastery) VALUES
    ((SELECT id FROM item_definitions WHERE name='Battleaxe'),   1, 0, '1d8',  2, '["Versatile (1d10)"]',                              'Topple'),
    ((SELECT id FROM item_definitions WHERE name='Flail'),       1, 0, '1d8',  0, '[]',                                                'Sap'),
    ((SELECT id FROM item_definitions WHERE name='Glaive'),      1, 0, '1d10', 2, '["Heavy","Reach","Two-Handed"]',                    'Graze'),
    ((SELECT id FROM item_definitions WHERE name='Greataxe'),    1, 0, '1d12', 2, '["Heavy","Two-Handed"]',                            'Cleave'),
    ((SELECT id FROM item_definitions WHERE name='Greatsword'),  1, 0, '2d6',  2, '["Heavy","Two-Handed"]',                            'Graze'),
    ((SELECT id FROM item_definitions WHERE name='Halberd'),     1, 0, '1d10', 2, '["Heavy","Reach","Two-Handed"]',                    'Cleave'),
    ((SELECT id FROM item_definitions WHERE name='Lance'),       1, 0, '1d10', 1, '["Heavy","Reach","Two-Handed (unless mounted)"]',   'Topple'),
    ((SELECT id FROM item_definitions WHERE name='Longsword'),   1, 0, '1d8',  2, '["Versatile (1d10)"]',                              'Sap'),
    ((SELECT id FROM item_definitions WHERE name='Maul'),        1, 0, '2d6',  0, '["Heavy","Two-Handed"]',                            'Topple'),
    ((SELECT id FROM item_definitions WHERE name='Morningstar'), 1, 0, '1d8',  1, '[]',                                                'Sap'),
    ((SELECT id FROM item_definitions WHERE name='Pike'),        1, 0, '1d10', 1, '["Heavy","Reach","Two-Handed"]',                    'Push'),
    ((SELECT id FROM item_definitions WHERE name='Rapier'),      1, 0, '1d8',  1, '["Finesse"]',                                       'Vex'),
    ((SELECT id FROM item_definitions WHERE name='Scimitar'),    1, 0, '1d6',  2, '["Finesse","Light"]',                               'Nick'),
    ((SELECT id FROM item_definitions WHERE name='Shortsword'),  1, 0, '1d6',  1, '["Finesse","Light"]',                               'Vex'),
    ((SELECT id FROM item_definitions WHERE name='Trident'),     1, 0, '1d8',  1, '["Thrown (Range 20/60)","Versatile (1d10)"]',       'Topple'),
    ((SELECT id FROM item_definitions WHERE name='Warhammer'),   1, 0, '1d8',  0, '["Versatile (1d10)"]',                              'Push'),
    ((SELECT id FROM item_definitions WHERE name='War Pick'),    1, 0, '1d8',  1, '["Versatile (1d10)"]',                              'Sap'),
    ((SELECT id FROM item_definitions WHERE name='Whip'),        1, 0, '1d4',  2, '["Finesse","Reach"]',                               'Slow');

-- ==============================
-- MARTIAL RANGED WEAPONS
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, source) VALUES
    ('Blowgun',        0, 1.0,   '10 GP',  0),
    ('Hand Crossbow',  0, 3.0,   '75 GP',  0),
    ('Heavy Crossbow', 0, 18.0,  '50 GP',  0),
    ('Longbow',        0, 2.0,   '50 GP',  0),
    ('Musket',         0, 10.0,  '500 GP', 0),
    ('Pistol',         0, 3.0,   '250 GP', 0);

INSERT INTO weapon_details (item_id, category, range_type, damage_dice, damage_type, properties, mastery, ammunition_type) VALUES
    ((SELECT id FROM item_definitions WHERE name='Blowgun'),        1, 1, '1',    1, '["Ammunition (Range 25/100)","Loading"]',                       'Vex',  'Needle'),
    ((SELECT id FROM item_definitions WHERE name='Hand Crossbow'),  1, 1, '1d6',  1, '["Ammunition (Range 30/120)","Light","Loading"]',               'Vex',  'Bolt'),
    ((SELECT id FROM item_definitions WHERE name='Heavy Crossbow'), 1, 1, '1d10', 1, '["Ammunition (Range 100/400)","Heavy","Loading","Two-Handed"]', 'Push', 'Bolt'),
    ((SELECT id FROM item_definitions WHERE name='Longbow'),        1, 1, '1d8',  1, '["Ammunition (Range 150/600)","Heavy","Two-Handed"]',           'Slow', 'Arrow'),
    ((SELECT id FROM item_definitions WHERE name='Musket'),         1, 1, '1d12', 1, '["Ammunition (Range 40/120)","Loading","Two-Handed"]',          'Slow', 'Bullet'),
    ((SELECT id FROM item_definitions WHERE name='Pistol'),         1, 1, '1d10', 1, '["Ammunition (Range 30/90)","Loading"]',                        'Vex',  'Bullet');

-- ==============================
-- AMMUNITION
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Arrow',          2, 0.05,  '1 GP', 'Stored in a Quiver.',             0),
    ('Bolt',           2, 0.075, '1 GP', 'Stored in a Crossbow Bolt Case.', 0),
    ('Firearm Bullet', 2, 0.2,   '3 GP', 'Stored in a Pouch.',              0),
    ('Sling Bullet',   2, 0.075, '4 CP', 'Stored in a Pouch.',              0),
    ('Needle',         2, 0.02,  '1 GP', 'Stored in a Pouch.',              0);