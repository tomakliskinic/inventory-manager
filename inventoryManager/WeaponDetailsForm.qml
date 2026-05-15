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

    function propChecked(index) {
        if (propertiesRepeater.count <= index) return false
        const cb = propertiesRepeater.itemAt(index)
        return cb ? cb.checked : false
    }
    readonly property bool ammunitionChecked: propChecked(0)
    readonly property bool thrownChecked: propChecked(6)
    readonly property bool versatileChecked: propChecked(8)

    readonly property bool isValid: {
        const dice = damageDiceField.text.trim()
        return /^[1-9]\d*(d[1-9]\d*)?$/.test(dice)
    }

    Label {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        text: qsTr("Weapon details")
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
            { id: Enums.WeaponCategory.Simple,  name: qsTr("Simple") },
            { id: Enums.WeaponCategory.Martial, name: qsTr("Martial") }
        ]
    }

    Label { text: qsTr("Range") }
    ComboBox {
        id: rangeField
        Layout.fillWidth: true
        textRole: "name"
        valueRole: "id"
        model: [
            { id: Enums.WeaponRangeType.Melee,  name: qsTr("Melee") },
            { id: Enums.WeaponRangeType.Ranged, name: qsTr("Ranged") }
        ]
    }

    Label { text: qsTr("Damage dice") }
    TextField {
        id: damageDiceField
        Layout.fillWidth: true
        placeholderText: qsTr("e.g. 1d8 or 1")
        validator: RegularExpressionValidator { regularExpression: /^[1-9]\d*(d[1-9]\d*)?$/ }
    }

    Label { text: qsTr("Damage type") }
    ComboBox {
        id: damageTypeField
        Layout.fillWidth: true
        textRole: "name"
        valueRole: "id"
        model: [
            { id: Enums.DamageType.Bludgeoning, name: qsTr("Bludgeoning") },
            { id: Enums.DamageType.Piercing,    name: qsTr("Piercing") },
            { id: Enums.DamageType.Slashing,    name: qsTr("Slashing") },
            { id: Enums.DamageType.Acid,        name: qsTr("Acid") },
            { id: Enums.DamageType.Cold,        name: qsTr("Cold") },
            { id: Enums.DamageType.Fire,        name: qsTr("Fire") },
            { id: Enums.DamageType.Force,       name: qsTr("Force") },
            { id: Enums.DamageType.Lightning,   name: qsTr("Lightning") },
            { id: Enums.DamageType.Necrotic,    name: qsTr("Necrotic") },
            { id: Enums.DamageType.Poison,      name: qsTr("Poison") },
            { id: Enums.DamageType.Psychic,     name: qsTr("Psychic") },
            { id: Enums.DamageType.Radiant,     name: qsTr("Radiant") },
            { id: Enums.DamageType.Thunder,     name: qsTr("Thunder") }
        ]
    }

    Label {
        text: qsTr("Properties")
        Layout.alignment: Qt.AlignTop
    }
    Flow {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            id: propertiesRepeater
            model: ["Ammunition", "Finesse", "Heavy", "Light", "Loading",
                    "Reach", "Thrown", "Two-Handed", "Versatile"]
            delegate: CheckBox {
                text: modelData
                padding: 4
                visible: {
                    const isRanged = rangeField.currentValue === Enums.WeaponRangeType.Ranged
                    if (isRanged)
                        return modelData !== "Reach" && modelData !== "Versatile"
                    return modelData !== "Ammunition" && modelData !== "Loading"
                }
                onToggled: {
                    function setOther(name, val) {
                        for (let i = 0; i < propertiesRepeater.count; i++) {
                            if (propertiesRepeater.model[i] === name) {
                                const cb = propertiesRepeater.itemAt(i)
                                if (cb) cb.checked = val
                                return
                            }
                        }
                    }
                    if (checked) {
                        if (modelData === "Heavy") setOther("Light", false)
                        else if (modelData === "Light") setOther("Heavy", false)
                        else if (modelData === "Two-Handed") setOther("Versatile", false)
                        else if (modelData === "Versatile") setOther("Two-Handed", false)
                        else if (modelData === "Loading") setOther("Ammunition", true)
                    } else {
                        if (modelData === "Ammunition") setOther("Loading", false)
                    }
                }
            }
        }
    }

    Label {
        text: qsTr("Versatile damage")
        visible: root.versatileChecked
    }
    TextField {
        id: versatileDiceField
        Layout.fillWidth: true
        visible: root.versatileChecked
        placeholderText: qsTr("two-handed dice, e.g. 1d10")
        validator: RegularExpressionValidator { regularExpression: /^[1-9]\d*(d[1-9]\d*)?$/ }
    }

    Label {
        text: qsTr("Thrown range (ft)")
        visible: root.thrownChecked
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: root.thrownChecked
        TextField {
            id: thrownShortField
            Layout.fillWidth: true
            placeholderText: qsTr("short")
            validator: IntValidator { bottom: 1; top: 9999 }
        }
        Label { text: "/" }
        TextField {
            id: thrownLongField
            Layout.fillWidth: true
            placeholderText: qsTr("long")
            validator: IntValidator { bottom: 1; top: 9999 }
        }
    }

    Label {
        text: qsTr("Ammunition range (ft)")
        visible: root.ammunitionChecked
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: root.ammunitionChecked
        TextField {
            id: ammoShortField
            Layout.fillWidth: true
            placeholderText: qsTr("short")
            validator: IntValidator { bottom: 1; top: 9999 }
        }
        Label { text: "/" }
        TextField {
            id: ammoLongField
            Layout.fillWidth: true
            placeholderText: qsTr("long")
            validator: IntValidator { bottom: 1; top: 9999 }
        }
    }

    Label { text: qsTr("Mastery") }
    ComboBox {
        id: masteryField
        Layout.fillWidth: true
        model: ["", "Cleave", "Graze", "Nick", "Push", "Sap", "Slow", "Topple", "Vex"]
        displayText: currentIndex === 0 ? qsTr("(none)") : currentText
        delegate: ItemDelegate {
            width: masteryField.width
            text: modelData === "" ? qsTr("(none)") : modelData
        }
    }

    Label {
        text: qsTr("Ammunition")
        visible: rangeField.currentValue === Enums.WeaponRangeType.Ranged
    }
    TextField {
        id: ammoTypeField
        Layout.fillWidth: true
        visible: rangeField.currentValue === Enums.WeaponRangeType.Ranged
        placeholderText: qsTr("e.g. Arrow (optional)")
    }

    function reset() {
        categoryField.currentIndex = 0
        rangeField.currentIndex = 0
        damageDiceField.text = ""
        damageTypeField.currentIndex = 0
        masteryField.currentIndex = 0
        ammoTypeField.text = ""
        for (let i = 0; i < propertiesRepeater.count; i++) {
            const cb = propertiesRepeater.itemAt(i)
            if (cb) cb.checked = false
        }
        versatileDiceField.text = ""
        thrownShortField.text = ""
        thrownLongField.text = ""
        ammoShortField.text = ""
        ammoLongField.text = ""
    }

    function load(item) {
        const wd = DB.getWeaponDetails(item.id)
        categoryField.currentIndex = wd.category !== undefined
            ? categoryField.model.findIndex(c => c.id === wd.category) : 0
        rangeField.currentIndex = wd.range_type !== undefined
            ? rangeField.model.findIndex(r => r.id === wd.range_type) : 0
        damageDiceField.text = wd.damage_dice || ""
        damageTypeField.currentIndex = wd.damage_type !== undefined
            ? damageTypeField.model.findIndex(d => d.id === wd.damage_type) : 0
        const masteryList = ["", "Cleave", "Graze", "Nick", "Push", "Sap", "Slow", "Topple", "Vex"]
        const masteryIdx = masteryList.indexOf(wd.mastery || "")
        masteryField.currentIndex = masteryIdx >= 0 ? masteryIdx : 0
        ammoTypeField.text = wd.ammunition_type || ""

        let savedProps = []
        try {
            const parsed = JSON.parse(wd.properties || "[]")
            if (Array.isArray(parsed)) savedProps = parsed
        } catch (e) { /* leave empty */ }
        for (let i = 0; i < propertiesRepeater.count; i++) {
            const cb = propertiesRepeater.itemAt(i)
            if (!cb) continue
            const name = propertiesRepeater.model[i]
            cb.checked = savedProps.some(p => typeof p === "string" && p.startsWith(name))
        }
        for (const p of savedProps) {
            if (typeof p !== "string") continue
            let m = p.match(/^Versatile \(([^)]+)\)$/)
            if (m) { versatileDiceField.text = m[1]; continue }
            m = p.match(/^Thrown \(Range (\d+)\/(\d+)\)$/)
            if (m) {
                thrownShortField.text = m[1]
                thrownLongField.text = m[2]
                continue
            }
            m = p.match(/^Ammunition \(Range (\d+)\/(\d+)\)$/)
            if (m) {
                ammoShortField.text = m[1]
                ammoLongField.text = m[2]
            }
        }
    }

    function serialize() {
        const isRanged = rangeField.currentValue === Enums.WeaponRangeType.Ranged
        const selectedProps = []
        for (let i = 0; i < propertiesRepeater.count; i++) {
            const cb = propertiesRepeater.itemAt(i)
            if (!cb || !cb.checked || !cb.visible) continue
            const name = propertiesRepeater.model[i]
            if (name === "Versatile") {
                const dice = versatileDiceField.text.trim()
                selectedProps.push(dice ? `Versatile (${dice})` : "Versatile")
            } else if (name === "Thrown") {
                const s = parseInt(thrownShortField.text)
                const l = parseInt(thrownLongField.text)
                selectedProps.push(s > 0 && l > 0 ? `Thrown (Range ${s}/${l})` : "Thrown")
            } else if (name === "Ammunition") {
                const s = parseInt(ammoShortField.text)
                const l = parseInt(ammoLongField.text)
                selectedProps.push(s > 0 && l > 0 ? `Ammunition (Range ${s}/${l})` : "Ammunition")
            } else {
                selectedProps.push(name)
            }
        }
        return {
            "category": categoryField.currentValue,
            "range_type": rangeField.currentValue,
            "damage_dice": damageDiceField.text.trim(),
            "damage_type": damageTypeField.currentValue,
            "properties": JSON.stringify(selectedProps),
            "mastery": masteryField.currentText || null,
            "ammunition_type": isRanged ? (ammoTypeField.text.trim() || null) : null
        }
    }
}
