-- ==============================
-- MAGIC CONTAINERS
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description,
    is_container, container_weight_capacity, container_volume_capacity, fixed_weight,
    rarity, requires_attunement, source) VALUES
    ('Bag of Holding', 4, 5.0, NULL,
        'Interior roughly 2 ft square and 4 ft deep. Weighs 5 lbs regardless of contents. Retrieving an item requires a Utilize action. If overloaded, pierced, or torn — destroyed, contents scattered in Astral Plane.',
        1, 500.0, 64.0, 5.0,
        1, 0, 0),

    ('Handy Haversack', 4, 5.0, NULL,
        'Has two side pouches (200 lbs / 25 cu ft each) and a central pouch (500 lbs / 64 cu ft). Weighs 5 lbs regardless of contents. Retrieving an item requires a Utilize or Bonus Action.',
        1, 900.0, 114.0, 5.0,
        2, 0, 0),

    ('Portable Hole', 4, 0.0, NULL,
        '6-foot-diameter, 10-foot-deep extradimensional hole when unfolded. Folds into cloth. Holds enough air for 1 hour of breathing.',
        1, NULL, 282.7, 0.0,
        2, 0, 0),

    ('Efficient Quiver', 4, 2.0, NULL,
        'Three compartments. Shortest: up to 60 Arrows/Bolts. Midsize: up to 18 Javelins. Longest: up to 6 long objects (bows, staves). Never weighs more than 2 lbs.',
        1, NULL, NULL, 2.0,
        1, 0, 0);

-- ==============================
-- COMMON MAGIC ITEMS (non-container)
-- ==============================

INSERT INTO item_definitions (name, item_type, weight_lb, cost, description, rarity, requires_attunement, source) VALUES
    ('Spell Scroll (Cantrip)', 4, 0.0, '30 GP', 'Cast the cantrip using its normal casting time. DC 13, +5 attack. Scroll disintegrates.', 0, 0, 0),
    ('Spell Scroll (Level 1)', 4, 0.0, '50 GP', 'Cast the level 1 spell using its normal casting time. DC 13, +5 attack. Scroll disintegrates.', 0, 0, 0),
    ('Potion of Greater Healing', 4, 0.5, NULL, 'Bonus Action. Regain 4d4+4 HP.', 1, 0, 0),
    ('Potion of Superior Healing', 4, 0.5, NULL, 'Bonus Action. Regain 8d4+8 HP.', 2, 0, 0),
    ('Potion of Supreme Healing', 4, 0.5, NULL, 'Bonus Action. Regain 10d4+20 HP.', 3, 0, 0);