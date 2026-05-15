import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

GridLayout {
    id: root
    columns: 2
    columnSpacing: 12
    rowSpacing: 8

    readonly property bool isShield: categoryField.currentValue === Enums.ArmorCategory.Shield
    readonly property bool isValid: true

    Label {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        text: qsTr("Armor details")
        font.bold: true
        Layout.topMargin: 8
    }

    Label { text: qsTr("Category") }
    ComboBox {
        id: categoryField
        Layout.fillWidth: true
        textRole: "name"
        valueRole: "id"
        model: [
            { id: Enums.ArmorCategory.Light,  name: qsTr("Light") },
            { id: Enums.ArmorCategory.Medium, name: qsTr("Medium") },
            { id: Enums.ArmorCategory.Heavy,  name: qsTr("Heavy") },
            { id: Enums.ArmorCategory.Shield, name: qsTr("Shield") }
        ]
        onActivated: {
            if (currentValue === Enums.ArmorCategory.Shield) {
                acBaseField.value = 2
                return
            }
            if (currentValue === Enums.ArmorCategory.Light) {
                acBaseField.value = 11
                donField.text     = "1"
                doffField.text    = "1"
                dexCapField.text  = ""
                stealthField.checked = false
            } else if (currentValue === Enums.ArmorCategory.Medium) {
                acBaseField.value = 13
                donField.text     = "5"
                doffField.text    = "1"
                dexCapField.text  = "2"
                stealthField.checked = false
            } else if (currentValue === Enums.ArmorCategory.Heavy) {
                acBaseField.value = 16
                donField.text     = "10"
                doffField.text    = "5"
                dexCapField.text  = "0"
                stealthField.checked = true
            }
        }
    }

    Label { text: root.isShield ? qsTr("AC bonus") : qsTr("Base AC") }
    SpinBox {
        id: acBaseField
        from: 1; to: 30
        value: 10
        editable: true
        Layout.fillWidth: true
    }

    Label {
        text: qsTr("Dex modifier cap")
        visible: !root.isShield
    }
    TextField {
        id: dexCapField
        Layout.fillWidth: true
        visible: !root.isShield
        placeholderText: qsTr("blank = no cap, 0 = no Dex, e.g. 2")
        validator: IntValidator { bottom: 0; top: 10 }
    }

    Label {
        text: qsTr("Strength required")
        visible: !root.isShield
    }
    TextField {
        id: strengthField
        Layout.fillWidth: true
        visible: !root.isShield
        placeholderText: qsTr("optional, e.g. 13")
        validator: IntValidator { bottom: 1; top: 30 }
    }

    Label {
        text: qsTr("Stealth disadvantage")
        visible: !root.isShield
    }
    CheckBox {
        id: stealthField
        visible: !root.isShield
    }

    Label {
        text: qsTr("Don time (min)")
        visible: !root.isShield
    }
    TextField {
        id: donField
        Layout.fillWidth: true
        visible: !root.isShield
        placeholderText: qsTr("optional")
        validator: IntValidator { bottom: 1; top: 60 }
    }

    Label {
        text: qsTr("Doff time (min)")
        visible: !root.isShield
    }
    TextField {
        id: doffField
        Layout.fillWidth: true
        visible: !root.isShield
        placeholderText: qsTr("optional")
        validator: IntValidator { bottom: 1; top: 60 }
    }

    function reset() {
        categoryField.currentIndex = 0
        acBaseField.value = 10
        dexCapField.text = ""
        strengthField.text = ""
        stealthField.checked = false
        donField.text = ""
        doffField.text = ""
    }

    function load(item) {
        const ad = DB.getArmorDetails(item.id)
        const catIdx = categoryField.model.findIndex(c => c.id === ad.category)
        categoryField.currentIndex = catIdx >= 0 ? catIdx : 0
        acBaseField.value = Number.isFinite(ad.ac_base) ? ad.ac_base : 10
        dexCapField.text = Number.isFinite(ad.ac_dex_max) ? ad.ac_dex_max.toString() : ""
        strengthField.text = Number.isFinite(ad.strength_required) ? ad.strength_required.toString() : ""
        stealthField.checked = !!ad.stealth_disadvantage
        donField.text = Number.isFinite(ad.don_minutes) ? ad.don_minutes.toString() : ""
        doffField.text = Number.isFinite(ad.doff_minutes) ? ad.doff_minutes.toString() : ""
    }

    function serialize() {
        const optInt = (s) => {
            const t = (s || "").trim()
            if (!t) return null
            const n = parseInt(t)
            return Number.isFinite(n) ? n : null
        }
        const shield = root.isShield
        return {
            "category": categoryField.currentValue,
            "ac_base": acBaseField.value,
            "ac_dex_max": shield ? null : optInt(dexCapField.text),
            "strength_required": shield ? null : optInt(strengthField.text),
            "stealth_disadvantage": shield ? 0 : (stealthField.checked ? 1 : 0),
            "don_minutes": shield ? null : optInt(donField.text),
            "doff_minutes": shield ? null : optInt(doffField.text)
        }
    }
}
