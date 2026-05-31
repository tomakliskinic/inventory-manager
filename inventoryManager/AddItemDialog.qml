import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root
    property int characterId: -1
    property var itemDefs: []
    property var containerOptions: []
    property string itemSearchText: ""
    property int itemFilterType: -1

    signal saved()
    signal failed(string message)

    readonly property var filteredItemDefs: {
        let result = itemDefs
        if (itemSearchText) {
            const needle = itemSearchText
            result = result.filter(i =>
                (i.name || "").toLowerCase().includes(needle))
        }
        if (itemFilterType >= 0)
            result = result.filter(i => i.item_type === itemFilterType)
        return result
    }

    title: qsTr("Add Item")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 460) - 32, 460)
    standardButtons: Dialog.Ok | Dialog.Cancel

    GridLayout {
        anchors.fill: parent
        columns: 2
        columnSpacing: 12
        rowSpacing: 8

        RowLayout {
            Layout.columnSpan: 2
            Layout.fillWidth: true

            TextField {
                id: itemSearchField
                Layout.fillWidth: true
                placeholderText: qsTr("Search…")
                onTextChanged: {
                    root.itemSearchText = text.trim().toLowerCase()
                    itemCombo.currentIndex = 0
                }
            }
            ComboBox {
                id: itemTypeFilter
                Layout.preferredWidth: 130
                textRole: "name"
                valueRole: "id"
                model: [
                    { id: -1, name: qsTr("All types") },
                    { id: Enums.ItemType.Weapon, name: qsTr("Weapons") },
                    { id: Enums.ItemType.Armor, name: qsTr("Armor") },
                    { id: Enums.ItemType.Gear, name: qsTr("Gear") },
                    { id: Enums.ItemType.Tool, name: qsTr("Tools") },
                    { id: Enums.ItemType.Magic, name: qsTr("Magic") }
                ]
                onActivated: {
                    root.itemFilterType = currentValue
                    itemCombo.currentIndex = 0
                }
            }
        }

        Label { text: qsTr("Item") }
        ComboBox {
            id: itemCombo
            Layout.fillWidth: true
            model: root.filteredItemDefs
            textRole: "name"
            valueRole: "id"
            Component.onCompleted: popup.bottomMargin = 80
        }

        Label { text: qsTr("Quantity") }
        SpinBox {
            id: qtyField
            Layout.fillWidth: true
            from: 1; to: 999; value: 1
            editable: true
        }

        Label { text: qsTr("Place in") }
        ComboBox {
            id: parentCombo
            Layout.fillWidth: true
            model: root.containerOptions
            textRole: "name"
            valueRole: "id"
            Component.onCompleted: popup.bottomMargin = 80
            delegate: ItemDelegate {
                width: ListView.view.width
                highlighted: parentCombo.highlightedIndex === index
                contentItem: Label {
                    text: modelData.name
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    function openFor(charId) {
        characterId = charId
        itemDefs = DB.getItemDefinitions()
        const allItems = DB.getInventoryTree(charId)
        const containers = allItems.filter(i => i.is_container)
        const opts = [{ id: -1, name: qsTr("Top level") }]
        for (const c of containers) {
            const path = []
            let cur = c
            while (cur) {
                path.unshift(cur.custom_name || cur.item_name)
                const parentId = cur.parent_inventory_item_id
                cur = parentId ? allItems.find(i => i.id === parentId) : null
            }
            opts.push({ id: c.id, name: path.join(" › ") })
        }
        containerOptions = opts
        itemSearchField.text = ""
        itemSearchText = ""
        itemTypeFilter.currentIndex = 0
        itemFilterType = -1
        itemCombo.currentIndex = 0
        qtyField.value = 1
        parentCombo.currentIndex = 0
        open()
    }

    onAccepted: {
        if (characterId > 0 && itemCombo.currentValue) {
            const newId = DB.addInventoryItem(characterId, itemCombo.currentValue, qtyField.value, parentCombo.currentValue)
            if (newId < 0)
                failed(DB.lastError() || qsTr("Couldn't add item."))
            saved()
        }
        characterId = -1
    }
    onRejected: characterId = -1
}
