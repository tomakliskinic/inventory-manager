import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Page {
    id: root
    property var character
    property var coins: ({})
    property real totalWeight: 0
    property real coinWeight: 0
    property real carryingCapacity: 0
    property var inventoryItems: []

    property string searchText: ""
    property bool searchInDescription: false
    property int filterType: -1
    property int filterSource: -1
    property int sortField: 0
    property bool sortAscending: true

    readonly property bool isFiltering: searchText !== "" || filterType >= 0 || filterSource >= 0

    signal back()
    signal editCharacterRequested(var character)
    signal exportRequested(int characterId)
    signal deleteCharacterRequested(var character)
    signal editCoinsRequested(int characterId)
    signal addItemRequested(int characterId)
    signal editItemRequested(var item)
    signal moveItemRequested(var item, int characterId)
    signal removeContainerRequested(var item, int characterId)
    signal removeItemRequested(var item)

    readonly property var filteredItems: {
        let result = inventoryItems

        if (isFiltering) {
            const matches = new Set()
            for (const item of inventoryItems) {
                const matchesSearch = !searchText
                    || (item.item_name || "").toLowerCase().includes(searchText)
                    || (item.custom_name || "").toLowerCase().includes(searchText)
                    || (item.notes || "").toLowerCase().includes(searchText)
                    || (searchInDescription && (item.item_description || "").toLowerCase().includes(searchText))
                const matchesType = filterType < 0 || item.item_type === filterType
                const matchesSource = filterSource < 0 || item.item_source === filterSource
                if (matchesSearch && matchesType && matchesSource)
                    matches.add(item.id)
            }
            const visible = new Set(matches)
            for (const id of matches) {
                const seed = inventoryItems.find(i => i.id === id)
                let parentId = seed ? seed.parent_inventory_item_id : null
                while (parentId && !visible.has(parentId)) {
                    visible.add(parentId)
                    const parent = inventoryItems.find(i => i.id === parentId)
                    parentId = parent ? parent.parent_inventory_item_id : null
                }
            }
            result = inventoryItems.filter(i => visible.has(i.id))
        }

        if (sortField > 0) {
            let cmp
            if (sortField === 1)
                cmp = (a, b) =>
                    (a.custom_name || a.item_name).localeCompare(b.custom_name || b.item_name)
            else if (sortField === 2)
                cmp = (a, b) => (a.weight_lb * a.quantity) - (b.weight_lb * b.quantity)
            else if (sortField === 3)
                cmp = (a, b) => a.quantity - b.quantity
            else
                cmp = (a, b) => (a.created_at || "").localeCompare(b.created_at || "")

            if (!sortAscending) {
                const inner = cmp
                cmp = (a, b) => -inner(a, b)
            }

            const byParent = {}
            for (const item of result) {
                const key = item.parent_inventory_item_id || 0
                if (!byParent[key]) byParent[key] = []
                byParent[key].push(item)
            }
            for (const key in byParent)
                byParent[key].sort(cmp)
            const ordered = []
            const walk = (parentId) => {
                const children = byParent[parentId] || []
                for (const child of children) {
                    ordered.push(child)
                    walk(child.id)
                }
            }
            walk(0)
            result = ordered
        }

        return result
    }

    function refresh() {
        if (!character) return
        character = DB.getCharacter(character.id)
        coins = DB.getCoins(character.id)
        totalWeight = DB.getTotalWeight(character.id)
        coinWeight = DB.getCoinWeight(character.id)
        carryingCapacity = DB.getCarryingCapacity(character.id)
        inventoryItems = DB.getInventoryTree(character.id)
    }

    Component.onCompleted: Qt.callLater(refresh)

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            spacing: 0

            ToolButton {
                text: "←"
                font.pixelSize: 20
                onClicked: root.back()
            }
            Label {
                text: root.character ? root.character.name : ""
                Layout.fillWidth: true
                elide: Label.ElideRight
                font.pixelSize: 18
            }
            ToolButton {
                text: qsTr("Edit")
                onClicked: root.editCharacterRequested(root.character)
            }
            ToolButton {
                text: qsTr("Export")
                onClicked: root.exportRequested(root.character.id)
            }
            ToolButton {
                text: qsTr("Delete")
                onClicked: root.deleteCharacterRequested(root.character)
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 12

            Frame {
                Layout.fillWidth: true
                Layout.margins: 16

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 8

                    Label { text: qsTr("Race"); font.bold: true }
                    Label { text: root.character ? (root.character.race || "—") : "" }

                    Label { text: qsTr("Class"); font.bold: true }
                    Label { text: root.character ? (root.character.class || "—") : "" }

                    Label { text: qsTr("Level"); font.bold: true }
                    Label { text: root.character ? root.character.level : "" }

                    Label { text: qsTr("Strength"); font.bold: true }
                    Label { text: root.character ? root.character.strength : "" }

                    Label { text: qsTr("Size"); font.bold: true }
                    Label {
                        text: root.character
                            ? DB.creatureSizeNames()[root.character.size] || "—"
                            : ""
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.margins: 16
                visible: root.character && root.character.notes

                ColumnLayout {
                    anchors.fill: parent

                    Label { text: qsTr("Notes"); font.bold: true }
                    Label {
                        text: root.character ? (root.character.notes || "") : ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.margins: 16

                ColumnLayout {
                    anchors.fill: parent

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: qsTr("Coins")
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Button {
                            text: qsTr("Edit")
                            flat: true
                            onClicked: root.editCoinsRequested(root.character.id)
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 5

                        Label { text: qsTr("CP"); Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; opacity: 0.7 }
                        Label { text: qsTr("SP"); Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; opacity: 0.7 }
                        Label { text: qsTr("EP"); Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; opacity: 0.7 }
                        Label { text: qsTr("GP"); Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; opacity: 0.7 }
                        Label { text: qsTr("PP"); Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; opacity: 0.7 }

                        Label { text: root.coins.cp || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                        Label { text: root.coins.sp || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                        Label { text: root.coins.ep || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                        Label { text: root.coins.gp || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                        Label { text: root.coins.pp || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.margins: 16

                ColumnLayout {
                    anchors.fill: parent

                    Label { text: qsTr("Weight"); font.bold: true }

                    Label {
                        text: qsTr("Carried: %1 / %2 lbs")
                            .arg(root.totalWeight.toFixed(1))
                            .arg(root.carryingCapacity.toFixed(0))
                    }
                    Label {
                        text: qsTr("Coin weight: %1 lbs").arg(root.coinWeight.toFixed(2))
                        opacity: 0.7
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        Layout.topMargin: 8

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.1)
                            radius: 3
                        }
                        Rectangle {
                            height: parent.height
                            width: parent.width * (root.carryingCapacity > 0
                                ? Math.min(root.totalWeight / root.carryingCapacity, 1)
                                : 0)
                            color: Material.accent
                            radius: 3
                        }
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.margins: 16

                ColumnLayout {
                    anchors.fill: parent

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: qsTr("Inventory")
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Button {
                            text: qsTr("+ Add")
                            flat: true
                            onClicked: root.addItemRequested(root.character.id)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.inventoryItems.length > 0

                        TextField {
                            Layout.fillWidth: true
                            placeholderText: qsTr("Search…")
                            onTextChanged: root.searchText = text.trim().toLowerCase()
                        }
                        CheckBox {
                            text: qsTr("Description")
                            checked: root.searchInDescription
                            onToggled: root.searchInDescription = checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.inventoryItems.length > 0

                        ComboBox {
                            Layout.fillWidth: true
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
                            onActivated: root.filterType = currentValue
                        }
                        ComboBox {
                            Layout.fillWidth: true
                            textRole: "name"
                            valueRole: "id"
                            model: [
                                { id: -1, name: qsTr("All sources") },
                                { id: Enums.ItemSource.SRD, name: qsTr("SRD") },
                                { id: Enums.ItemSource.Homebrew, name: qsTr("Homebrew") }
                            ]
                            onActivated: root.filterSource = currentValue
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.inventoryItems.length > 0

                        ComboBox {
                            Layout.fillWidth: true
                            textRole: "name"
                            valueRole: "id"
                            model: [
                                { id: 0, name: qsTr("Default order") },
                                { id: 1, name: qsTr("Name") },
                                { id: 2, name: qsTr("Weight") },
                                { id: 3, name: qsTr("Quantity") },
                                { id: 4, name: qsTr("Date added") }
                            ]
                            onActivated: {
                                root.sortField = currentValue
                                root.sortAscending = currentValue === 1
                            }
                        }
                        ToolButton {
                            text: root.sortAscending ? "↑" : "↓"
                            enabled: root.sortField > 0
                            onClicked: root.sortAscending = !root.sortAscending
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: root.inventoryItems.length === 0
                        text: qsTr("No items")
                        opacity: 0.5
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: root.inventoryItems.length > 0
                                 && root.filteredItems.length === 0
                        text: qsTr("No items match.")
                        opacity: 0.5
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Repeater {
                        model: root.filteredItems
                        delegate: RowLayout {
                            Layout.fillWidth: true

                            Item {
                                Layout.preferredWidth: modelData.depth * 20
                                visible: modelData.depth > 0
                            }
                            Label {
                                text: (modelData.is_container ? "📦 " : "")
                                      + (modelData.custom_name || modelData.item_name)
                                      + (modelData.is_equipped ? " ✓" : "")
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Label {
                                text: qsTr("×%1").arg(modelData.quantity)
                                opacity: 0.7
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }
                            Label {
                                text: qsTr("%1 lb").arg((modelData.weight_lb * modelData.quantity).toFixed(1))
                                opacity: 0.7
                                Layout.preferredWidth: 60
                                horizontalAlignment: Text.AlignRight
                            }
                            ToolButton {
                                text: "…"
                                font.pixelSize: 16
                                onClicked: {
                                    inventoryRowMenu.item = modelData
                                    inventoryRowMenu.popup()
                                }
                            }
                        }
                    }

                    Menu {
                        id: inventoryRowMenu
                        property var item: null

                        MenuItem {
                            text: qsTr("Edit")
                            onTriggered: root.editItemRequested(inventoryRowMenu.item)
                        }
                        MenuItem {
                            text: qsTr("Move")
                            onTriggered: root.moveItemRequested(inventoryRowMenu.item, root.character.id)
                        }
                        MenuItem {
                            text: qsTr("Remove")
                            onTriggered: {
                                const it = inventoryRowMenu.item
                                if (it.is_container && DB.getContainerContents(it.id).length > 0)
                                    root.removeContainerRequested(it, root.character.id)
                                else
                                    root.removeItemRequested(it)
                            }
                        }
                    }
                }
            }
        }
    }
}
