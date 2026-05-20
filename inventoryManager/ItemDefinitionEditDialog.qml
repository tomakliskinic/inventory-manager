import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root
    property int editingId: -1

    signal saveFailed(string message)
    signal saved()

    readonly property bool isValid: {
        if (!itemDefNameField.text.trim()) return false
        if (itemDefTypeField.currentValue === Enums.ItemType.Weapon && !weaponForm.isValid)
            return false
        return true
    }

    readonly property bool containerEligible: {
        const t = itemDefTypeField.currentValue
        return t !== Enums.ItemType.Weapon && t !== Enums.ItemType.Armor
    }

    onOpened: {
        const okBtn = standardButton(Dialog.Ok)
        if (okBtn) okBtn.enabled = Qt.binding(() => isValid)
    }

    title: editingId === -1 ? qsTr("New Item") : qsTr("Edit Item")
    modal: true
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 500) - 32, 500)
    height: Math.min((parent ? parent.height : 620) - 60, 620)
    standardButtons: Dialog.Ok | Dialog.Cancel

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        GridLayout {
            width: root.availableWidth - 20
            columns: 2
            columnSpacing: 12
            rowSpacing: 8

            Label { text: qsTr("Name") }
            TextField {
                id: itemDefNameField
                Layout.fillWidth: true
            }

            Label { text: qsTr("Type") }
            ComboBox {
                id: itemDefTypeField
                Layout.fillWidth: true
                textRole: "name"
                valueRole: "id"
                model: [
                    { id: Enums.ItemType.Weapon, name: qsTr("Weapon") },
                    { id: Enums.ItemType.Armor, name: qsTr("Armor") },
                    { id: Enums.ItemType.Gear, name: qsTr("Gear") },
                    { id: Enums.ItemType.Tool, name: qsTr("Tool") },
                    { id: Enums.ItemType.Magic, name: qsTr("Magic") }
                ]
                onActivated: {
                    if (currentValue !== Enums.ItemType.Weapon) weaponForm.reset()
                    if (currentValue !== Enums.ItemType.Armor)  armorForm.reset()
                }
            }

            Label { text: qsTr("Weight (lb)") }
            TextField {
                id: itemDefWeightField
                Layout.fillWidth: true
                validator: DoubleValidator { bottom: 0; decimals: 2; notation: DoubleValidator.StandardNotation }
                placeholderText: "0.0"
            }

            Label { text: qsTr("Cost") }
            RowLayout {
                Layout.fillWidth: true
                SpinBox {
                    id: itemDefCostAmountField
                    from: 0; to: 99999
                    Layout.fillWidth: true
                    editable: true
                }
                ComboBox {
                    id: itemDefCostCurrencyField
                    Layout.preferredWidth: 80
                    model: ["CP", "SP", "EP", "GP", "PP"]
                    currentIndex: 3
                }
            }

            Label { text: qsTr("Rarity") }
            ComboBox {
                id: itemDefRarityField
                Layout.fillWidth: true
                textRole: "name"
                valueRole: "id"
                model: [
                    { id: -1, name: qsTr("None") },
                    { id: Enums.ItemRarity.Common, name: qsTr("Common") },
                    { id: Enums.ItemRarity.Uncommon, name: qsTr("Uncommon") },
                    { id: Enums.ItemRarity.Rare, name: qsTr("Rare") },
                    { id: Enums.ItemRarity.VeryRare, name: qsTr("Very Rare") },
                    { id: Enums.ItemRarity.Legendary, name: qsTr("Legendary") },
                    { id: Enums.ItemRarity.Artifact, name: qsTr("Artifact") }
                ]
            }

            Label { text: qsTr("Attunement") }
            CheckBox {
                id: itemDefAttunementField
            }

            Label {
                text: qsTr("Container")
                visible: root.containerEligible
            }
            CheckBox {
                id: itemDefIsContainerField
                visible: root.containerEligible
            }

            Label {
                text: qsTr("Capacity (lb)")
                visible: root.containerEligible && itemDefIsContainerField.checked
            }
            TextField {
                id: itemDefCapacityField
                Layout.fillWidth: true
                visible: root.containerEligible && itemDefIsContainerField.checked
                validator: DoubleValidator { bottom: 0; decimals: 2; notation: DoubleValidator.StandardNotation }
                placeholderText: qsTr("optional weight limit")
            }

            Label {
                text: qsTr("Fixed weight (lb)")
                visible: root.containerEligible && itemDefIsContainerField.checked
            }
            TextField {
                id: itemDefFixedWeightField
                Layout.fillWidth: true
                visible: root.containerEligible && itemDefIsContainerField.checked
                validator: DoubleValidator { bottom: 0; decimals: 2; notation: DoubleValidator.StandardNotation }
                placeholderText: qsTr("e.g. Bag of Holding")
            }

            WeaponDetailsForm {
                id: weaponForm
                Layout.columnSpan: 2
                Layout.fillWidth: true
                visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
            }

            ArmorDetailsForm {
                id: armorForm
                Layout.columnSpan: 2
                Layout.fillWidth: true
                visible: itemDefTypeField.currentValue === Enums.ItemType.Armor
            }

            Label {
                text: qsTr("Description")
                Layout.alignment: Qt.AlignTop
            }
            ScrollView {
                id: itemDefDescScroll
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                clip: true

                function ensureCursorVisible(r) {
                    const flick = contentItem
                    const margin = 6
                    const top = r.y - margin
                    const bottom = r.y + r.height + margin
                    if (top < flick.contentY)
                        flick.contentY = Math.max(0, top)
                    else if (bottom > flick.contentY + flick.height)
                        flick.contentY = Math.min(
                            bottom - flick.height,
                            Math.max(0, flick.contentHeight - flick.height))
                }

                TextArea {
                    id: itemDefDescField
                    wrapMode: TextArea.Wrap
                    onCursorRectangleChanged: itemDefDescScroll.ensureCursorVisible(cursorRectangle)
                }
            }
        }
    }

    function resetForm() {
        editingId = -1
        itemDefNameField.text = ""
        itemDefTypeField.currentIndex = 0
        itemDefWeightField.text = ""
        itemDefCostAmountField.value = 0
        itemDefCostCurrencyField.currentIndex = 3
        itemDefRarityField.currentIndex = 0
        itemDefAttunementField.checked = false
        itemDefIsContainerField.checked = false
        itemDefCapacityField.text = ""
        itemDefFixedWeightField.text = ""
        itemDefDescField.text = ""
        weaponForm.reset()
        armorForm.reset()
    }

    function openCreate() {
        resetForm()
        open()
    }

    function openEdit(item) {
        editingId = item.id
        itemDefNameField.text = item.name || ""

        const typeIdx = itemDefTypeField.model.findIndex(t => t.id === item.item_type)
        itemDefTypeField.currentIndex = typeIdx >= 0 ? typeIdx : 0

        itemDefWeightField.text = Number.isFinite(item.weight_lb) ? item.weight_lb.toString() : "0"

        let costAmount = 0
        let costCurrencyIdx = 3
        if (item.cost) {
            const match = item.cost.match(/^(\d+)\s+(CP|SP|EP|GP|PP)$/)
            if (match) {
                costAmount = parseInt(match[1])
                costCurrencyIdx = ["CP", "SP", "EP", "GP", "PP"].indexOf(match[2])
            }
        }
        itemDefCostAmountField.value = costAmount
        itemDefCostCurrencyField.currentIndex = costCurrencyIdx

        if (Number.isFinite(item.rarity)) {
            const rIdx = itemDefRarityField.model.findIndex(r => r.id === item.rarity)
            itemDefRarityField.currentIndex = rIdx >= 0 ? rIdx : 0
        } else {
            itemDefRarityField.currentIndex = 0
        }

        itemDefAttunementField.checked = !!item.requires_attunement
        itemDefIsContainerField.checked = !!item.is_container
        itemDefCapacityField.text = Number.isFinite(item.container_weight_capacity)
            ? item.container_weight_capacity.toString() : ""
        itemDefFixedWeightField.text = Number.isFinite(item.fixed_weight)
            ? item.fixed_weight.toString() : ""

        itemDefDescField.text = item.description || ""

        if (item.item_type === Enums.ItemType.Weapon) {
            weaponForm.load(item)
        } else if (item.item_type === Enums.ItemType.Armor) {
            armorForm.load(item)
        }
        open()
    }

    onAccepted: {
        const name = itemDefNameField.text.trim()
        if (!name) {
            resetForm()
            return
        }

        const costAmount = itemDefCostAmountField.value
        const containerOn = containerEligible && itemDefIsContainerField.checked
        const data = {
            "name": name,
            "item_type": itemDefTypeField.currentValue,
            "weight_lb": parseFloat(itemDefWeightField.text) || 0,
            "cost": costAmount > 0 ? (costAmount + " " + itemDefCostCurrencyField.currentText) : null,
            "description": itemDefDescField.text.trim() || null,
            "is_container": containerOn ? 1 : 0,
            "requires_attunement": itemDefAttunementField.checked ? 1 : 0
        }
        if (itemDefRarityField.currentValue !== undefined && itemDefRarityField.currentValue >= 0)
            data.rarity = itemDefRarityField.currentValue
        if (containerOn) {
            const cap = parseFloat(itemDefCapacityField.text)
            if (cap > 0) data.container_weight_capacity = cap
            const fw = parseFloat(itemDefFixedWeightField.text)
            if (fw > 0) data.fixed_weight = fw
        }

        const weaponData = weaponForm.serialize()
        const armorData = armorForm.serialize()
        const savedId = DB.saveItemDefinition(editingId, data, weaponData, armorData)
        if (savedId < 0)
            root.saveFailed(DB.lastError() || qsTr("Couldn't save item."))
        else
            root.saved()
        resetForm()
    }
    onRejected: resetForm()
}
