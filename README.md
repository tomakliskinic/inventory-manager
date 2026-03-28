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

This project is in early development. The feature list above reflects the full planned scope — not all features are implemented yet.

## Tech Stack

| Technology | Purpose |
|---|---|
| Qt 6 / QML | UI framework and cross-platform layer |
| C++ | Application logic |
| SQLite | Local persistent database |
| JSON | Data import/export |
| Git / GitHub | Version control |

## Changelog

### 2026-03-28
- SQLite schema added: 6 tables (characters, character_coins, item_definitions, weapon_details, armor_details, inventory_items)

### 2026-03-15
- Initial project setup — repository and README created

## Disclaimer

This is an unofficial fan project and is not affiliated with, endorsed by, or in any way officially connected to Wizards of the Coast or Dungeons & Dragons. All D&D-related terms and rules are the property of Wizards of the Coast.

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.
