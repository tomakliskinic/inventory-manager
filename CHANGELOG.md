## Changelog

### 2026-05-23
- Cost and value formatting helpers extracted into a shared piece so every page uses one definition
- Narrow-screen detection extracted into a single window-level property reused by every page header
- ... overflow menu (used on rows and headers) extracted into a reusable piece that handles right-alignment and flip-upward when near the screen edge
- Character edit, coins editor, add item, inventory item editor, move item, and remove-container dialogs each reorganized as self-contained pieces extracted from the main window
- Inventory row layout reorganized as a reusable piece extracted from the character detail page

### 2026-05-22
- Custom Android app identity: treasure-chest icon at all densities, "Inventory Manager" label in the launcher and recents, splash screen during startup
- Android orientation locked to portrait, and the app is removed from Recents when exited via the quit prompt
- Unused Android permissions removed from the install prompt (Bluetooth, camera, audio)
- Tap any non-container inventory row to open its item info dialog; "View info" added to every row's ... menu so containers (whose tap toggles expansion) also have a path to it
- Item info dialog shrinks to fit short content instead of holding a fixed height with empty space below
- Row ... menus on character, catalog, and inventory rows drop down from their button, right-aligned, and flip upward when the button is near the bottom of the screen so the menu doesn't clip off-screen

### 2026-05-21
- Sort by Cost in the item catalog and in a character's inventory; cost text is parsed into copper pieces so mixed currencies compare correctly
- Character detail page shows total inventory value, broken into the largest denominations (PP, GP, SP, CP)
- Weight and Cost sort on the inventory now use container aggregates, so a backpack full of heavy gear outranks a single greataxe
- Container weight column shows the aggregate in parens next to the container's own weight when the contents add weight
- Fixed-weight containers (Bag of Holding, Handy Haversack) still report only their own weight, matching the carry-weight rule
- Header toolbars collapse secondary actions into a `…` overflow menu on narrow screens, so phone headers stop clipping
- Character list title now actually centered on the toolbar instead of drifting left
- Linux desktop build verified on Linux Mint 22.1 with Qt 6.11
- Back gesture on Android or Esc on desktop from the character list opens an exit prompt; Yes exits the app, No stays
- Containers in a character's inventory start collapsed; tap a container row to expand or collapse it
- Active search or filter reveals matching items inside collapsed containers via their ancestor chain
- Hover and press highlight on inventory rows limited to container rows; non-container rows stay visually inert

### 2026-05-20
- Native Android keyboard opens correctly
- Back gesture pops the navigation stack when past the character list
- Menu glyph swapped to one Android's default font can render
- Dialogs scale down to fit narrow screens
- Catalog and inventory search bars use a three-row layout (search + Description checkbox, type + source filters, sort + direction toggle) so each field gets full width
- Inventory gains source filter and Description-search checkbox; catalog gains Name/Weight sort with direction toggle

### 2026-05-19
- Item catalog gains an Export button that writes all homebrew items to a JSON file, with weapon and armor type-specific details inlined per item
- Item catalog gains an Import button; items whose names already exist in the catalog are skipped with a banner listing them, and the rest are added as homebrew

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