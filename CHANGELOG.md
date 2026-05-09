## Changelog

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