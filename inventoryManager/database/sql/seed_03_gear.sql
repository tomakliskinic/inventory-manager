-- ==============================
-- CONTAINERS (is_container = 1)
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, is_container, container_weight_capacity, container_volume_capacity, source) VALUES
    ('Backpack',            2, 5.0,  '2 GP', 'Holds up to 30 pounds within 1 cubic foot. Can also serve as a saddlebag.', 1, 30.0, 1.0,  0),
    ('Barrel',              2, 70.0, '2 GP', 'Holds up to 40 gallons of liquid or up to 4 cubic feet of dry goods.',      1, NULL, 4.0,  0),
    ('Basket',              2, 2.0,  '4 SP', 'Holds up to 40 pounds within 2 cubic feet.',                                1, 40.0, 2.0,  0),
    ('Bucket',              2, 2.0,  '5 CP', 'Holds up to half a cubic foot of contents.',                                1, NULL, 0.5,  0),
    ('Case, Crossbow Bolt', 2, 1.0,  '1 GP', 'Holds up to 20 Bolts.',                                                     1, NULL, NULL, 0),
    ('Case, Map or Scroll', 2, 1.0,  '1 GP', 'Holds up to 10 sheets of paper or 5 sheets of parchment.',                  1, NULL, NULL, 0),
    ('Chest',               2, 25.0, '5 GP', 'Holds up to 12 cubic feet of contents.',                                    1, NULL, 12.0, 0),
    ('Glass Bottle',        2, 2.0,  '2 GP', 'Holds up to 1.5 pints.',                                                    1, NULL, NULL, 0),
    ('Flask',               2, 1.0,  '2 CP', 'Holds up to 1 pint.',                                                       1, NULL, NULL, 0),
    ('Jug',                 2, 4.0,  '2 CP', 'Holds up to 1 gallon.',                                                     1, NULL, NULL, 0),
    ('Iron Pot',            2, 10.0, '2 GP', 'Holds up to 1 gallon.',                                                     1, NULL, NULL, 0),
    ('Pouch',               2, 1.0,  '5 SP', 'Holds up to 6 pounds within one-fifth of a cubic foot.',                    1, 6.0,  0.2,  0),
    ('Quiver',              2, 1.0,  '1 GP', 'Holds up to 20 Arrows.',                                                    1, NULL, NULL, 0),
    ('Sack',                2, 0.5,  '1 CP', 'Holds up to 30 pounds within 1 cubic foot.',                                1, 30.0, 1.0,  0),
    ('Vial',                2, 0.0,  '1 GP', 'Holds up to 4 ounces.',                                                     1, NULL, NULL, 0),
    ('Waterskin',           2, 5.0,  '2 SP', 'Holds up to 4 pints. Weight listed is when full.',                          1, NULL, NULL, 0);

-- ==============================
-- NON-CONTAINER GEAR
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Acid',                 2, 1.0,  '25 GP',    'Throw as attack. DC 8+DEX+Prof, 2d6 Acid damage.',                        0),
    ('Alchemist''s Fire',    2, 1.0,  '50 GP',    'Throw as attack. DC 8+DEX+Prof, 1d4 Fire damage, target starts Burning.', 0),
    ('Antitoxin',            2, 0.0,  '50 GP',    'Bonus Action to drink. Advantage on saves vs Poisoned for 1 hour.',       0),
    ('Ball Bearings',        2, 2.0,  '1 GP',     'Cover 10-ft square. DC 10 DEX save or Prone.',                            0),
    ('Bedroll',              2, 7.0,  '1 GP',     'Auto-succeed saves against extreme cold while inside.',                   0),
    ('Bell',                 2, 0.0,  '1 GP',     'Sound audible up to 60 feet.',                                            0),
    ('Blanket',              2, 3.0,  '5 SP',     'Advantage on saves against extreme cold.',                                0),
    ('Block and Tackle',     2, 5.0,  '1 GP',     'Hoist up to 4x your normal lift weight.',                                 0),
    ('Book',                 2, 5.0,  '25 GP',    'Nonfiction book gives +5 to relevant INT checks.',                        0),
    ('Caltrops',             2, 2.0,  '1 GP',     'Cover 5-ft square. DC 15 DEX save or 1 Piercing + Speed 0.',              0),
    ('Candle',               2, 0.0,  '1 CP',     'Bright Light 5 ft, Dim Light +5 ft for 1 hour.',                          0),
    ('Chain',                2, 10.0, '5 GP',     'Bind creature. DC 20 STR to burst, DC 18 DEX to escape.',                 0),
    ('Climber''s Kit',       2, 12.0, '25 GP',    'Anchor yourself. Can''t fall more than 25 ft from anchor.',               0),
    ('Clothes, Fine',        2, 6.0,  '15 GP',    'Required for some events and locations.',                                 0),
    ('Clothes, Traveler''s', 2, 4.0,  '2 GP',     'Resilient garments for travel.',                                          0),
    ('Component Pouch',      2, 2.0,  '25 GP',    'Holds all free Material components for spells.',                          0),
    ('Costume',              2, 4.0,  '5 GP',     'Advantage on checks to impersonate.',                                     0),
    ('Crowbar',              2, 5.0,  '2 GP',     'Advantage on STR checks where leverage applies.',                         0),
    ('Grappling Hook',       2, 4.0,  '2 GP',     'Throw up to 50 ft. DC 13 DEX (Acrobatics) to catch.',                     0),
    ('Healer''s Kit',        2, 3.0,  '5 GP',     '10 uses. Utilize action to stabilize creature at 0 HP.',                  0),
    ('Holy Water',           2, 1.0,  '25 GP',    'Throw as attack. DC 8+DEX+Prof, 2d8 Radiant vs Fiend/Undead.',            0),
    ('Hunting Trap',         2, 25.0, '5 GP',     'DC 13 DEX save or 1d4 Piercing + Speed 0.',                               0),
    ('Ink',                  2, 0.0,  '10 GP',    '1-ounce bottle. Enough for ~500 pages.',                                  0),
    ('Ink Pen',              2, 0.0,  '2 CP',     'Used with Ink to write or draw.',                                         0),
    ('Ladder',               2, 25.0, '1 SP',     '10 feet tall.',                                                           0),
    ('Lamp',                 2, 1.0,  '5 SP',     'Burns Oil. Bright Light 15 ft, Dim Light +30 ft.',                        0),
    ('Lantern, Bullseye',    2, 2.0,  '10 GP',    'Burns Oil. Bright Light 60-ft Cone, Dim Light +60 ft.',                   0),
    ('Lantern, Hooded',      2, 2.0,  '5 GP',     'Burns Oil. Bright Light 30 ft, Dim Light +30 ft. Lowerable.',             0),
    ('Lock',                 2, 1.0,  '10 GP',    'DC 15 DEX (Sleight of Hand) to pick with Thieves'' Tools.',               0),
    ('Magnifying Glass',     2, 0.0,  '100 GP',   'Advantage on checks to appraise/inspect detailed items.',                 0),
    ('Manacles',             2, 6.0,  '2 GP',     'DC 20 DEX to escape, DC 25 STR to burst.',                                0),
    ('Map',                  2, 0.0,  '1 GP',     '+5 WIS (Survival) to navigate the mapped area.',                          0),
    ('Mirror',               2, 0.5,  '5 GP',     'Handheld steel mirror.',                                                  0),
    ('Net',                  2, 3.0,  '1 GP',     'Throw as attack within 15 ft. Target Restrained. DC 10 STR to escape.',   0),
    ('Oil',                  2, 1.0,  '1 SP',     'Burns 6 hours in Lamp/Lantern. Douse for +5 Fire damage.',                0),
    ('Paper',                2, 0.0,  '2 SP',     'One sheet, ~250 handwritten words.',                                      0),
    ('Parchment',            2, 0.0,  '1 SP',     'One sheet, ~250 handwritten words.',                                      0),
    ('Perfume',              2, 0.0,  '5 GP',     'Advantage on CHA (Persuasion) vs Indifferent Humanoid within 5 ft.',      0),
    ('Poison, Basic',        2, 0.0,  '100 GP',   'Bonus Action to coat weapon. +1d4 Poison damage for 1 minute.',           0),
    ('Pole',                 2, 7.0,  '5 CP',     '10 feet long. Advantage on jump checks when vaulting.',                   0),
    ('Potion of Healing',    2, 0.5,  '50 GP',    'Bonus Action. Regain 2d4+2 HP. Magic item.',                              0),
    ('Ram, Portable',        2, 35.0, '4 GP',     '+4 STR to break doors. Another character can help for Advantage.',        0),
    ('Rations',              2, 2.0,  '5 SP',     'One day of travel-ready food.',                                           0),
    ('Robe',                 2, 4.0,  '1 GP',     'Ceremonial significance. Required for some events.',                      0),
    ('Rope',                 2, 5.0,  '1 GP',     '50 feet. DC 10 DEX to tie, DC 20 STR to burst.',                          0),
    ('Shovel',               2, 5.0,  '2 GP',     'Dig 5-ft cube in 1 hour.',                                                0),
    ('Signal Whistle',       2, 0.0,  '5 CP',     'Audible up to 600 feet.',                                                 0),
    ('Spikes, Iron',         2, 5.0,  '1 GP',     'Bundle of 10. Jam doors or anchor rope/chain.',                           0),
    ('Spyglass',             2, 1.0,  '1,000 GP', 'Objects magnified to 2x size.',                                           0),
    ('String',               2, 0.0,  '1 SP',     '10 feet long.',                                                           0),
    ('Tent',                 2, 20.0, '2 GP',     'Sleeps 2 Small or Medium creatures.',                                     0),
    ('Tinderbox',            2, 1.0,  '5 SP',     'Bonus Action to light exposed fuel. 1 minute for other fires.',           0),
    ('Torch',                2, 1.0,  '1 CP',     'Bright Light 20 ft, Dim Light +20 ft for 1 hour. 1 Fire on hit.',         0);

-- ==============================
-- ARCANE FOCUSES
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Arcane Focus: Crystal', 2, 1.0, '10 GP', 'Spellcasting Focus for Sorcerer, Warlock, or Wizard.',                   0),
    ('Arcane Focus: Orb',     2, 3.0, '20 GP', 'Spellcasting Focus for Sorcerer, Warlock, or Wizard.',                   0),
    ('Arcane Focus: Rod',     2, 2.0, '10 GP', 'Spellcasting Focus for Sorcerer, Warlock, or Wizard.',                   0),
    ('Arcane Focus: Staff',   2, 4.0, '5 GP',  'Spellcasting Focus Sorcerer, Warlock, or Wizard (also a Quarterstaff).', 0),
    ('Arcane Focus: Wand',    2, 1.0, '10 GP', 'Spellcasting Focus for Sorcerer, Warlock, or Wizard.',                   0);

-- ==============================
-- DRUIDIC FOCUSES
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Druidic Focus: Sprig of Mistletoe', 2, 0.0, '1 GP',  'Spellcasting Focus for Druid or Ranger.',                       0),
    ('Druidic Focus: Wooden Staff',       2, 4.0, '5 GP',  'Spellcasting Focus for Druid or Ranger (also a Quarterstaff).', 0),
    ('Druidic Focus: Yew Wand',           2, 1.0, '10 GP', 'Spellcasting Focus for Druid or Ranger.',                       0);

-- ==============================
-- HOLY SYMBOLS
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Holy Symbol: Amulet',    2, 1.0, '5 GP', 'Spellcasting Focus for Cleric or Paladin. Worn or held.',              0),
    ('Holy Symbol: Emblem',    2, 0.0, '5 GP', 'Spellcasting Focus for Cleric or Paladin. Borne on fabric or Shield.', 0),
    ('Holy Symbol: Reliquary', 2, 2.0, '5 GP', 'Spellcasting Focus for Cleric or Paladin. Held.',                      0);

-- ==============================
-- PACKS (pre-made bundles)
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, is_container, container_weight_capacity, container_volume_capacity, source) VALUES
    ('Burglar''s Pack',     2, 42.0,  '16 GP', 'Contains: Backpack, Ball Bearings, Bell, 10 Candles, Crowbar, Hooded Lantern, 7 flasks of Oil, 5 days of Rations, Rope, Tinderbox, Waterskin.',
        1, 30.0, 1.0,  0),
    ('Diplomat''s Pack',    2, 39.0,  '39 GP', 'Contains: Chest, Fine Clothes, Ink, 5 Ink Pens, Lamp, 2 Map/Scroll Cases, 4 flasks of Oil, 5 sheets of Paper, 5 sheets of Parchment, Perfume, Tinderbox.',
        1, NULL, 12.0, 0),
    ('Dungeoneer''s Pack',  2, 55.0,  '12 GP', 'Contains: Backpack, Caltrops, Crowbar, 2 flasks of Oil, 10 days of Rations, Rope, Tinderbox, 10 Torches, Waterskin.',
        1, 30.0, 1.0,  0),
    ('Entertainer''s Pack', 2, 58.5,  '40 GP', 'Contains: Backpack, Bedroll, Bell, Bullseye Lantern, 3 Costumes, Mirror, 8 flasks of Oil, 9 days of Rations, Tinderbox, Waterskin.',
        1, 30.0, 1.0,  0),
    ('Explorer''s Pack',    2, 55.0,  '10 GP', 'Contains: Backpack, Bedroll, 2 flasks of Oil, 10 days of Rations, Rope, Tinderbox, 10 Torches, Waterskin.',
        1, 30.0, 1.0,  0),
    ('Priest''s Pack',      2, 29.0,  '33 GP', 'Contains: Backpack, Blanket, Holy Water, Lamp, 7 days of Rations, Robe, Tinderbox.',
        1, 30.0, 1.0,  0),
    ('Scholar''s Pack',     2, 22.0,  '40 GP', 'Contains: Backpack, Book, Ink, Ink Pen, Lamp, 10 flasks of Oil, 10 sheets of Parchment, Tinderbox.',
        1, 30.0, 1.0,  0);