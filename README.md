# D&D 5E-Compatible Inventory Management System

A cross-platform desktop and mobile application for managing character inventories in compliance with Dungeons & Dragons 5th Edition rules. Built with Qt 6.

## Overview
This application lets players create and manage characters and their inventories, with automatic calculations for weight, carry capacity, and other D&D 5E-defined statistics. All data updates dynamically with every inventory change.

## Features

### Character & Item Management
- Create, edit, and delete characters with core attributes (name, level, strength, size, race, class, notes)
- Coin tracking per character across five denominations (CP, SP, EP, GP, PP), counted toward encumbrance
- Create, edit, and delete Homebrew items via a browseable catalog with name, type, weight, cost, rarity, attunement, container flags, and description
- Per-type structured details with SRD-anchored validation: Weapons (category, range, damage dice, properties, mastery, ammunition) and Armor (category, AC, Dex cap, strength, stealth, don/doff times)
- Input validation throughout (positive quantities, non-empty names, capacity constraints)
- Per-character inventory view with a clear display of all associated items and their attributes

### Inventory Management & Organization
- Add items to a character's inventory and define quantities; stackable Gear/Tool items auto-merge
- Move items between containers; remove items with three modes for non-empty containers (spill to parent, delete with contents, move contents elsewhere)
- **Container system** — organize items in a hierarchical structure (e.g. bags within bags); each container collapses/expands per character
- Sort items by name, weight, cost, quantity, or date added; weight and cost sort aggregate container contents
- Filter items by type, source (SRD / Homebrew), or full-text search with optional description match
- Automatic calculation of total inventory weight, encumbrance relative to carry capacity, and total inventory value broken into the largest coin denominations — updated in real time on every change

### Data Storage & Exchange
- Persistent storage using a local **SQLite** database with referential integrity (FK constraints across relations)
- Seeded SRD catalog of 100+ items (Weapons, Armor, Gear, Tools, Magic) available from first launch
- **JSON export/import of characters** — single or all — for backups and transfer between devices
- **JSON export/import of Homebrew item packs** so custom items can be shared across installs; selectively export only a chosen subset of homebrew items
- Import paths validate structure, skip name conflicts with a warning, and wrap multi-step writes in a transaction; character import skips re-imports of identical character data so duplicate-name characters with different contents still come through as new entries

### Local Network Sharing
- Auto-discovers other app instances on the same network via UDP broadcast — no configuration; peers appear as they join and drop off after a short idle window
- Editable device name (persisted across launches; defaults to the system hostname) in the Peers dialog reachable from the item catalog
- **Share homebrew packs** with a tapped peer — selection mode in the catalog lets you ship a single item or a curated subset; receiver gets an accept/decline prompt showing the sender and item count
- **Hand off inventory items between characters across devices** — pick an item from a character's inventory, choose a quantity for stackable items, pick a peer; receiver picks which of their characters receives it
- Containers travel with their contents in a single transfer, so giving away a stuffed backpack hands the whole subtree across
- Two-phase accept/decline action on item transfers: the sender's item only leaves their inventory after the receiver accepts, so declined transfers leave both sides untouched

### Cross-Platform Support
- Responsive UI built with **QML**, adapted for different screen sizes (header overflow menus and three-row search bars on narrow phones)
- Light and dark themes with the choice persisted across launches
- Runs on **Windows desktop**, **Linux desktop**, and **Android**
- Custom Android packaging: app icon, splash screen, portrait lock, exit-clears-recents

## Project Status

Active development. See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## Tech Stack

| Technology | Purpose |
|---|---|
| Qt 6 / QML | UI framework and cross-platform layer |
| C++ | Application logic |
| SQLite | Local persistent database |
| JSON | Data import/export |
| Qt Network | UDP peer discovery and TCP transfer |
| Git / GitHub | Version control |

## Disclaimer

This is an unofficial fan project and is not affiliated with, endorsed by, or in any way officially connected to Wizards of the Coast or Dungeons & Dragons. All D&D-related terms and rules are the property of Wizards of the Coast.

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.