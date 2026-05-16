## Changelog

### 2026-05-16
- Weapon edit subform (category, range, damage, properties grid, mastery, ammunition) reorganized as a reusable piece within the item edit dialog
- Armor edit subform (category, base AC, Dex cap, strength, stealth, don/doff) reorganized the same way
- Item view dialog, item edit dialog, and character detail page each reorganized to be self-contained

### 2026-05-15
- Item view dialog displays armor-specific fields (category, AC formula formatted per category, strength required, stealth disadvantage, don/doff times) when present
- Homebrew armor edit gains an armor section (category, base AC, Dex modifier cap, strength required, stealth, don/doff minutes); Shield collapses to category + AC bonus only; switching an item's type cleans up the prior detail row
- Category-driven prefill in armor edit according to SRD: picking Light/Medium/Heavy/Shield auto-fills AC base, don/doff, Dex cap, and stealth

### 2026-05-14
- Item view dialog displays weapon-specific fields (category, range, damage dice + type, properties, mastery, ammunition type) when present
- Homebrew weapon edit gains a weapon section: category, range, damage dice (regex-validated), damage type, mastery, and ammunition type (only when Ranged); container fields hidden on Weapon/Armor; item + weapon_details written in a single transaction
- Weapon properties multi-select: 9-checkbox grid with range-type filtering (Reach/Versatile melee-only, Ammunition/Loading ranged-only), parameterized inputs for Versatile/Thrown/Ammunition saved in SRD seed format, and SRD invariants enforced (Heavy excludes Light, Two-Handed excludes Versatile, Loading requires Ammunition)

### 2026-05-13
- Edit and delete actions for Homebrew item definitions, reachable from a per-row ⋮ menu (SRD entries stay view-only and have no menu)
- Delete pre-check reports "item is in use" when the definition is referenced by any character's inventory, instead of surfacing a generic FK error

### 2026-05-12
- Browseable item catalog reachable from the character list header; supports search (with optional description match), filter by type, and filter by source (All / SRD / Homebrew)
- Read-only item detail dialog on row tap showing all common fields with NULL-safe visibility
- Create Homebrew item definitions via "+ Add" dialog covering name, type, weight, cost (amount + currency picker), rarity, attunement, container flag with optional capacity and fixed weight, and description

### 2026-05-11
- JSON export of all characters from the list page, or a single character from the detail page; items are referenced by name for portability across installations that share the SRD seed catalog
- JSON import recreates characters with their coins and full inventory tree in a transaction; unknown item names are skipped with a warning
- Success notifications now use a green variant of the banner

### 2026-05-10
- Search and type filter for the inventory list and the Add Item catalog
- Sort by name, weight, quantity, or date added, with an ascending/descending toggle; sorting respects container hierarchy (siblings are ordered within their parent)
- Filtering preserves tree shape by including each match's ancestor chain so depth-based indentation continues to make sense

### 2026-05-09
- Inventory items can be moved between containers via row menu; destination picker excludes the item itself and its descendants
- Edit and Remove for inventory items, with mode picker (Spill / Delete with contents / Move to another container) for non-empty containers
- Backend validation errors (capacity, cross-character, cycle) now surfaced in the UI via an auto-dismissing banner
- Non-stackable bulk adds (Weapons, Armor, Magic, containers) create distinct rows so each instance has its own identity

### 2026-05-01
- Hierarchical inventory display with depth-based indentation
- Add Item dialog supports placing items into existing containers via a path-formatted destination picker (e.g. "Bag of Holding › Backpack")

### 2026-04-27
- Character management UI built on QML with StackView navigation and Material light theme
- Character list with create/edit/delete and per-row menu
- Character detail page with coins, weight bar, and inventory list
- Esc-to-back navigation across pages and dialogs

### 2026-04-26
- Inventory backend polish: log message standardization, automatic stacking of fungible Gear/Tool items
- QML plumbing: Q_INVOKABLE annotations, Enums namespace registered for QML, virtual keyboard restricted to mobile platforms

### 2026-04-24
- Three removal modes for non-empty containers: spill to parent, delete with all contents, move contents to another container
- Cross-character container operations rejected
- Item removal wrapped in a transaction
- Input validation tightened in addInventoryItem and updateCoins

### 2026-04-12
- Container weight capacity enforced up the entire ancestor chain
- Partial-update bugs fixed (updates no longer null out unspecified columns)
- getTotalWeight now includes coin weight
- Character name validation on create and update
- getContainerUsedWeight delegated to a shared interiorWeight helper

### 2026-04-11
- updateCharacter only writes the fields explicitly provided
- getTotalWeight respects fixed-weight containers (Bag of Holding semantics)

### 2026-04-06
- DatabaseManager added: schema/seed initialization, CRUD operations for characters, inventory and coins, 5E weight calculations (some are still todo)
- SQL files embedded in Qt resource system

### 2026-04-05
- C++ enum definitions added (enums.h): CreatureSize, ItemType, ItemSource, ItemRarity, WeaponCategory, WeaponRangeType, DamageType, ArmorCategory

### 2026-03-28
- SQLite schema added: 6 tables (characters, character_coins, item_definitions, weapon_details, armor_details, inventory_items)

### 2026-03-15
- Initial project setup — repository and README created