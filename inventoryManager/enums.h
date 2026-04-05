#ifndef ENUMS_H
#define ENUMS_H

#include <QString>

namespace Enums {
Q_NAMESPACE

enum class CreatureSize {
    Tiny = 0,
    Small = 1,
    Medium = 2,
    Large = 3,
    Huge = 4,
    Gargantuan = 5
};
Q_ENUM_NS(CreatureSize)

enum class ItemType {
    Weapon = 0,
    Armor = 1,
    Gear = 2,
    Tool = 3,
    Magic = 4
};
Q_ENUM_NS(ItemType)

enum class ItemSource {
    SRD = 0,
    Homebrew = 1
};
Q_ENUM_NS(ItemSource)

enum class ItemRarity {
    Common = 0,
    Uncommon = 1,
    Rare = 2,
    VeryRare = 3,
    Legendary = 4,
    Artifact = 5
};
Q_ENUM_NS(ItemRarity)

enum class WeaponCategory {
    Simple = 0,
    Martial = 1
};
Q_ENUM_NS(WeaponCategory)

enum class WeaponRangeType {
    Melee = 0,
    Ranged = 1
};
Q_ENUM_NS(WeaponRangeType)

enum class DamageType {
    Bludgeoning = 0,
    Piercing = 1,
    Slashing = 2,
    Acid = 3,
    Cold = 4,
    Fire = 5,
    Force = 6,
    Lightning = 7,
    Necrotic = 8,
    Poison = 9,
    Psychic = 10,
    Radiant = 11,
    Thunder = 12
};
Q_ENUM_NS(DamageType)

enum class ArmorCategory {
    Light = 0,
    Medium = 1,
    Heavy = 2,
    Shield = 3
};
Q_ENUM_NS(ArmorCategory)

static inline QString toString(CreatureSize v) {
    switch (v) {
        case Enums::CreatureSize::Tiny: return QStringLiteral("Tiny");
        case Enums::CreatureSize::Small: return QStringLiteral("Small");
        case Enums::CreatureSize::Medium: return QStringLiteral("Medium");
        case Enums::CreatureSize::Large: return QStringLiteral("Large");
        case Enums::CreatureSize::Huge: return QStringLiteral("Huge");
        case Enums::CreatureSize::Gargantuan: return QStringLiteral("Gargantuan");
    }
        return QStringLiteral("Unknown");
}

static inline QString toString(ItemType v) {
    switch (v) {
        case Enums::ItemType::Weapon: return QStringLiteral("Weapon");
        case Enums::ItemType::Armor: return QStringLiteral("Armor");
        case Enums::ItemType::Gear: return QStringLiteral("Gear");
        case Enums::ItemType::Tool: return QStringLiteral("Tool");
        case Enums::ItemType::Magic: return QStringLiteral("Magic");
    }
        return QStringLiteral("Unknown");
}

static inline QString toString(ItemSource v) {
    switch (v) {
        case Enums::ItemSource::SRD: return QStringLiteral("SRD");
        case Enums::ItemSource::Homebrew: return QStringLiteral("Homebrew");
    }
        return QStringLiteral("Unknown");
}

static inline QString toString(ItemRarity v) {
    switch (v) {
        case Enums::ItemRarity::Common: return QStringLiteral("Common");
        case Enums::ItemRarity::Uncommon: return QStringLiteral("Uncommon");
        case Enums::ItemRarity::Rare: return QStringLiteral("Rare");
        case Enums::ItemRarity::VeryRare: return QStringLiteral("VeryRare");
        case Enums::ItemRarity::Legendary: return QStringLiteral("Legendary");
        case Enums::ItemRarity::Artifact: return QStringLiteral("Artifact");
    }
        return QStringLiteral("Unknown");
}

static inline QString toString(WeaponCategory v) {
    switch (v) {
        case Enums::WeaponCategory::Simple: return QStringLiteral("Simple");
        case Enums::WeaponCategory::Martial: return QStringLiteral("Martial");
    }
        return QStringLiteral("Unknown");
}

static inline QString toString(WeaponRangeType v) {
    switch (v) {
        case Enums::WeaponRangeType::Melee: return QStringLiteral("Melee");
        case Enums::WeaponRangeType::Ranged: return QStringLiteral("Ranged");
    }
        return QStringLiteral("Unknown");
}

static inline QString toString(DamageType v) {
    switch (v) {
        case Enums::DamageType::Bludgeoning: return QStringLiteral("Bludgeoning");
        case Enums::DamageType::Piercing: return QStringLiteral("Piercing");
        case Enums::DamageType::Slashing: return QStringLiteral("Slashing");
        case Enums::DamageType::Acid: return QStringLiteral("Acid");
        case Enums::DamageType::Cold: return QStringLiteral("Cold");
        case Enums::DamageType::Fire: return QStringLiteral("Fire");
        case Enums::DamageType::Force: return QStringLiteral("Force");
        case Enums::DamageType::Lightning: return QStringLiteral("Lightning");
        case Enums::DamageType::Necrotic: return QStringLiteral("Necrotic");
        case Enums::DamageType::Poison: return QStringLiteral("Poison");
        case Enums::DamageType::Psychic: return QStringLiteral("Psychic");
        case Enums::DamageType::Radiant: return QStringLiteral("Radiant");
        case Enums::DamageType::Thunder: return QStringLiteral("Thunder");
    }
        return QStringLiteral("Unknown");
}

static inline QString toString(ArmorCategory v) {
    switch (v) {
        case Enums::ArmorCategory::Light: return QStringLiteral("Light");
        case Enums::ArmorCategory::Medium: return QStringLiteral("Medium");
        case Enums::ArmorCategory::Heavy: return QStringLiteral("Heavy");
        case Enums::ArmorCategory::Shield: return QStringLiteral("Shield");
    }
        return QStringLiteral("Unknown");
}

static inline double carryMultiplier(CreatureSize size) {
    switch (size) {
        case Enums::CreatureSize::Tiny: return 7.5;
        case Enums::CreatureSize::Small: return 15.0;
        case Enums::CreatureSize::Medium: return 15.0;
        case Enums::CreatureSize::Large: return 30.0;
        case Enums::CreatureSize::Huge: return 60.0;
        case Enums::CreatureSize::Gargantuan: return 120.0;
    }
        return 15.0;
}
}

#endif // ENUMS_H
