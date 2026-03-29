-- ==============================
-- ARTISAN'S TOOLS
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Alchemist''s Supplies',    3, 8.0,  '50 GP', 'INT. Identify substance (DC 15), start fire (DC 15).',                0),
    ('Brewer''s Supplies',       3, 9.0,  '20 GP', 'INT. Detect poisoned drink (DC 15), identify alcohol (DC 10).',       0),
    ('Calligrapher''s Supplies', 3, 5.0, '10 GP',  'DEX. Write with flourishes that guard against forgery (DC 15).',      0),
    ('Carpenter''s Tools',       3, 6.0,  '8 GP',  'STR. Seal or pry open a door or container (DC 20).',                  0),
    ('Cartographer''s Tools',    3, 6.0,  '15 GP', 'WIS. Draft a map of a small area (DC 15).',                           0),
    ('Cobbler''s Tools',         3, 5.0,  '5 GP',  'DEX. Modify footwear for Advantage on next Acrobatics (DC 10).',      0),
    ('Cook''s Utensils',         3, 8.0,  '1 GP',  'WIS. Improve food flavor (DC 10), detect spoiled/poisoned (DC 15).',  0),
    ('Glassblower''s Tools',     3, 5.0,  '30 GP', 'INT. Discern what a glass object held in past 24h (DC 15).',          0),
    ('Jeweler''s Tools',         3, 2.0,  '25 GP', 'INT. Discern a gem''s value (DC 15).',                                0),
    ('Leatherworker''s Tools',   3, 5.0,  '5 GP',  'DEX. Add a design to a leather item (DC 10).',                        0),
    ('Mason''s Tools',           3, 8.0,  '10 GP', 'STR. Chisel a symbol or hole in stone (DC 10).',                      0),
    ('Painter''s Supplies',      3, 5.0,  '10 GP', 'WIS. Paint a recognizable image of something seen (DC 10).',          0),
    ('Potter''s Tools',          3, 3.0,  '10 GP', 'INT. Discern what a ceramic held in past 24h (DC 15).',               0),
    ('Smith''s Tools',           3, 8.0,  '20 GP', 'STR. Pry open a door or container (DC 20).',                          0),
    ('Tinker''s Tools',          3, 10.0, '50 GP', 'DEX. Assemble a Tiny item from scrap (DC 20). Falls apart in 1 min.', 0),
    ('Weaver''s Tools',          3, 5.0,  '1 GP',  'DEX. Mend a tear in clothing (DC 10), sew a Tiny design (DC 10).',    0),
    ('Woodcarver''s Tools',      3, 5.0,  '1 GP',  'DEX. Carve a pattern in wood (DC 10).',                               0);

-- ==============================
-- OTHER TOOLS
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Disguise Kit',       3, 3.0, '25 GP', 'CHA. Apply makeup (DC 10).',                                       0),
    ('Forgery Kit',        3, 5.0, '15 GP', 'DEX. Mimic handwriting (DC 15), duplicate wax seal (DC 20).',      0),
    ('Herbalism Kit',      3, 3.0, '5 GP',  'INT. Identify a plant (DC 10).',                                   0),
    ('Navigator''s Tools', 3, 2.0, '25 GP', 'WIS. Plot a course (DC 10), determine position by stars (DC 15).', 0),
    ('Poisoner''s Kit',    3, 2.0, '50 GP', 'INT. Detect a poisoned object (DC 10).',                           0),
    ('Thieves'' Tools',    3, 1.0, '25 GP', 'DEX. Pick a lock (DC 15), disarm a trap (DC 15).',                 0);

-- ==============================
-- GAMING SETS (variants)
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Gaming Set: Dice',              3, 0.0, '1 SP', 'WIS. Discern cheating (DC 10), win the game (DC 20).', 0),
    ('Gaming Set: Dragonchess',       3, 0.0, '1 GP', 'WIS. Discern cheating (DC 10), win the game (DC 20).', 0),
    ('Gaming Set: Playing Cards',     3, 0.0, '5 SP', 'WIS. Discern cheating (DC 10), win the game (DC 20).', 0),
    ('Gaming Set: Three-Dragon Ante', 3, 0.0, '1 GP', 'WIS. Discern cheating (DC 10), win the game (DC 20).', 0);

-- ==============================
-- MUSICAL INSTRUMENTS (variants)
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, source) VALUES
    ('Musical Instrument: Bagpipes',  3, 6.0,  '30 GP', 'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Drum',      3, 3.0,  '6 GP',  'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Dulcimer',  3, 10.0, '25 GP', 'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Flute',     3, 1.0,  '2 GP',  'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Horn',      3, 2.0,  '3 GP',  'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Lute',      3, 2.0,  '35 GP', 'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Lyre',      3, 2.0,  '30 GP', 'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Pan Flute', 3, 2.0,  '12 GP', 'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Shawm',     3, 1.0,  '2 GP',  'CHA. Play a known tune (DC 10), improvise (DC 15).', 0),
    ('Musical Instrument: Viol',      3, 1.0,  '30 GP', 'CHA. Play a known tune (DC 10), improvise (DC 15).', 0);