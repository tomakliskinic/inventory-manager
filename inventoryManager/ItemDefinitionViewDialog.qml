import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root
    property var item: null
    property var weaponDetails: ({})
    property var armorDetails: ({})

    readonly property bool isWeapon: !!item && item.item_type === Enums.ItemType.Weapon
    readonly property bool isArmor: !!item && item.item_type === Enums.ItemType.Armor

    function openFor(it) {
        item = it
        weaponDetails = (it && it.item_type === Enums.ItemType.Weapon)
            ? DB.getWeaponDetails(it.id) : ({})
        armorDetails = (it && it.item_type === Enums.ItemType.Armor)
            ? DB.getArmorDetails(it.id) : ({})
        open()
    }

    title: item ? item.name : ""
    modal: true
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 480) - 32, 480)
    height: Math.min((parent ? parent.height : 600) - 60, 600)
    standardButtons: Dialog.Close

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        GridLayout {
            width: root.availableWidth - 20
            columns: 2
            columnSpacing: 16
            rowSpacing: 8

            Label { text: qsTr("Type"); font.bold: true }
            Label {
                text: root.item
                    ? (["Weapon", "Armor", "Gear", "Tool", "Magic"][root.item.item_type] || "—")
                    : ""
            }

            Label { text: qsTr("Weight"); font.bold: true }
            Label {
                text: root.item
                    ? qsTr("%1 lb").arg(root.item.weight_lb.toFixed(1))
                    : ""
            }

            Label {
                text: qsTr("Cost"); font.bold: true
                visible: root.item && root.item.cost
            }
            Label {
                text: root.item ? (root.item.cost || "") : ""
                visible: root.item && root.item.cost
            }

            Label {
                text: qsTr("Rarity"); font.bold: true
                visible: root.item && Number.isFinite(root.item.rarity)
            }
            Label {
                text: root.item
                    ? (["Common", "Uncommon", "Rare", "Very Rare", "Legendary", "Artifact"][root.item.rarity] || "")
                    : ""
                visible: root.item && Number.isFinite(root.item.rarity)
            }

            Label {
                text: qsTr("Attunement"); font.bold: true
                visible: root.item && root.item.requires_attunement
            }
            Label {
                text: qsTr("Required")
                visible: root.item && root.item.requires_attunement
            }

            Label {
                text: qsTr("Container"); font.bold: true
                visible: root.item && root.item.is_container
            }
            Label {
                text: qsTr("Yes")
                visible: root.item && root.item.is_container
            }

            Label {
                text: qsTr("Capacity"); font.bold: true
                visible: root.item && root.item.is_container
                         && Number.isFinite(root.item.container_weight_capacity)
                         && root.item.container_weight_capacity > 0
            }
            Label {
                text: root.item && Number.isFinite(root.item.container_weight_capacity)
                    ? qsTr("%1 lb").arg(root.item.container_weight_capacity.toFixed(0))
                    : ""
                visible: root.item && root.item.is_container
                         && Number.isFinite(root.item.container_weight_capacity)
                         && root.item.container_weight_capacity > 0
            }

            Label {
                text: qsTr("Fixed weight"); font.bold: true
                visible: root.item
                         && Number.isFinite(root.item.fixed_weight)
                         && root.item.fixed_weight > 0
            }
            Label {
                text: root.item && Number.isFinite(root.item.fixed_weight)
                    ? qsTr("%1 lb").arg(root.item.fixed_weight.toFixed(1))
                    : ""
                visible: root.item
                         && Number.isFinite(root.item.fixed_weight)
                         && root.item.fixed_weight > 0
            }

            Label { text: qsTr("Source"); font.bold: true }
            Label {
                text: root.item
                    ? (root.item.source === Enums.ItemSource.Homebrew ? qsTr("Homebrew") : qsTr("SRD"))
                    : ""
            }

            Label {
                text: qsTr("Category"); font.bold: true
                visible: root.isWeapon
                         && Number.isFinite(root.weaponDetails.category)
            }
            Label {
                text: root.isWeapon
                    ? (["Simple", "Martial"][root.weaponDetails.category] || "")
                    : ""
                visible: root.isWeapon
                         && Number.isFinite(root.weaponDetails.category)
            }

            Label {
                text: qsTr("Range"); font.bold: true
                visible: root.isWeapon
                         && Number.isFinite(root.weaponDetails.range_type)
            }
            Label {
                text: root.isWeapon
                    ? (["Melee", "Ranged"][root.weaponDetails.range_type] || "")
                    : ""
                visible: root.isWeapon
                         && Number.isFinite(root.weaponDetails.range_type)
            }

            Label {
                text: qsTr("Damage"); font.bold: true
                visible: root.isWeapon
                         && !!root.weaponDetails.damage_dice
            }
            Label {
                text: {
                    if (!root.isWeapon) return ""
                    const wd = root.weaponDetails
                    const damageTypes = ["Bludgeoning", "Piercing", "Slashing", "Acid", "Cold", "Fire",
                        "Force", "Lightning", "Necrotic", "Poison", "Psychic", "Radiant", "Thunder"]
                    const dt = damageTypes[wd.damage_type] || ""
                    return (wd.damage_dice || "") + (dt ? " " + dt : "")
                }
                visible: root.isWeapon
                         && !!root.weaponDetails.damage_dice
            }

            Label {
                text: qsTr("Properties"); font.bold: true
                Layout.alignment: Qt.AlignTop
                visible: root.isWeapon
                         && !!root.weaponDetails.properties
                         && root.weaponDetails.properties !== "[]"
            }
            Label {
                text: {
                    if (!root.isWeapon) return ""
                    try {
                        const arr = JSON.parse(root.weaponDetails.properties || "[]")
                        return arr.join(", ")
                    } catch (e) {
                        return ""
                    }
                }
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: root.isWeapon
                         && !!root.weaponDetails.properties
                         && root.weaponDetails.properties !== "[]"
            }

            Label {
                text: qsTr("Mastery"); font.bold: true
                visible: root.isWeapon
                         && !!root.weaponDetails.mastery
            }
            Label {
                text: root.isWeapon
                    ? (root.weaponDetails.mastery || "")
                    : ""
                visible: root.isWeapon
                         && !!root.weaponDetails.mastery
            }

            Label {
                text: qsTr("Ammunition"); font.bold: true
                visible: root.isWeapon
                         && !!root.weaponDetails.ammunition_type
            }
            Label {
                text: root.isWeapon
                    ? (root.weaponDetails.ammunition_type || "")
                    : ""
                visible: root.isWeapon
                         && !!root.weaponDetails.ammunition_type
            }

            Label {
                text: qsTr("Armor category"); font.bold: true
                visible: root.isArmor
                         && Number.isFinite(root.armorDetails.category)
            }
            Label {
                text: root.isArmor
                    ? (["Light", "Medium", "Heavy", "Shield"][root.armorDetails.category] || "")
                    : ""
                visible: root.isArmor
                         && Number.isFinite(root.armorDetails.category)
            }

            Label {
                text: qsTr("Armor Class"); font.bold: true
                visible: root.isArmor
                         && Number.isFinite(root.armorDetails.ac_base)
            }
            Label {
                text: {
                    if (!root.isArmor) return ""
                    const ad = root.armorDetails
                    if (ad.category === Enums.ArmorCategory.Shield)
                        return "+" + ad.ac_base
                    if (ad.category === Enums.ArmorCategory.Heavy)
                        return "" + ad.ac_base
                    if (Number.isFinite(ad.ac_dex_max) && ad.ac_dex_max > 0)
                        return ad.ac_base + " + Dex modifier (max " + ad.ac_dex_max + ")"
                    return ad.ac_base + " + Dex modifier"
                }
                visible: root.isArmor
                         && Number.isFinite(root.armorDetails.ac_base)
            }

            Label {
                text: qsTr("Strength required"); font.bold: true
                visible: root.isArmor
                         && Number.isFinite(root.armorDetails.strength_required)
                         && root.armorDetails.strength_required > 0
            }
            Label {
                text: root.isArmor && Number.isFinite(root.armorDetails.strength_required)
                    ? ("Str " + root.armorDetails.strength_required) : ""
                visible: root.isArmor
                         && Number.isFinite(root.armorDetails.strength_required)
                         && root.armorDetails.strength_required > 0
            }

            Label {
                text: qsTr("Stealth"); font.bold: true
                visible: root.isArmor
                         && !!root.armorDetails.stealth_disadvantage
            }
            Label {
                text: qsTr("Disadvantage")
                visible: root.isArmor
                         && !!root.armorDetails.stealth_disadvantage
            }

            Label {
                text: qsTr("Don / Doff"); font.bold: true
                visible: root.isArmor
                         && (Number.isFinite(root.armorDetails.don_minutes)
                             || Number.isFinite(root.armorDetails.doff_minutes))
            }
            Label {
                text: {
                    if (!root.isArmor) return ""
                    const ad = root.armorDetails
                    const don = Number.isFinite(ad.don_minutes) ? ad.don_minutes + " min" : "—"
                    const doff = Number.isFinite(ad.doff_minutes) ? ad.doff_minutes + " min" : "—"
                    return don + " / " + doff
                }
                visible: root.isArmor
                         && (Number.isFinite(root.armorDetails.don_minutes)
                             || Number.isFinite(root.armorDetails.doff_minutes))
            }

            Label {
                text: qsTr("Description"); font.bold: true
                Layout.alignment: Qt.AlignTop
                visible: root.item && root.item.description
            }
            Label {
                text: root.item ? (root.item.description || "") : ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: root.item && root.item.description
            }
        }
    }

    onClosed: item = null
}
