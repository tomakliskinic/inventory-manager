# D&D 5E-Compatible Inventory Management System

A cross-platform desktop and mobile application for managing character inventories in compliance with Dungeons & Dragons 5th Edition rules. Built with Qt 6.

## Overview

This application will allow players to create and manage characters and their inventories, with automatic calculations for weight, carry capacity, and other D&D 5E-defined statistics. All data will update dynamically with every inventory change.

## Planned Features

### Character & Item Management
- Create, edit, and delete characters with core attributes (name, level, carry capacity, etc.)
- Create, edit, and delete items with properties such as name, type, weight, value, and description
- Input validation to prevent invalid values (e.g. negative quantities)
- Per-character inventory view with a clear display of all associated items and their attributes

### Inventory Management & Organization
- Add items to a character's inventory and define quantities
- Move items within the inventory
- **Container system** — organize items in a hierarchical structure (e.g. bags within bags), with full container and content display
- Sort items by various criteria (name, weight, value)
- Filter items by type or other attributes
- Dynamic search across the inventory
- Automatic calculation of total inventory weight, encumbrance relative to carry capacity, and other 5E-relevant stats — updated in real time on every change

### Data Storage & Exchange
- Persistent storage using a local **SQLite** database with referential integrity
- **JSON export** for backups or transferring data between devices
- **JSON import** with structure validation

### Cross-Platform Support
- Responsive UI built with **QML**, adapted for different screen sizes
- Targeting **desktop** (Windows / Linux) and **mobile** (Android)

## Project Status

Active development. The core inventory management loop is functional: character CRUD, hierarchical inventory with nested containers (collapsible per character), item add/edit/move/remove with stacking for fungibles, coin tracking, search/filter/sort (including by name, weight, and cost with container-aware aggregation), live weight/capacity calculations against D&D 5E carry rules, total inventory value broken into the largest coin denominations, JSON export/import of characters (single or all), a browseable item catalog with full CRUD on Homebrew items including weapon and armor type-specific details with SRD-anchored validation, and JSON export/import of Homebrew item packs. Items are picked from the seeded SRD catalog plus any Homebrew entries you add. Builds and runs on Windows desktop, Linux desktop, and Android, with ongoing mobile polish.

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## Tech Stack

| Technology | Purpose |
|---|---|
| Qt 6 / QML | UI framework and cross-platform layer |
| C++ | Application logic |
| SQLite | Local persistent database |
| JSON | Data import/export |
| Git / GitHub | Version control |

## Disclaimer

This is an unofficial fan project and is not affiliated with, endorsed by, or in any way officially connected to Wizards of the Coast or Dungeons & Dragons. All D&D-related terms and rules are the property of Wizards of the Coast.

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.