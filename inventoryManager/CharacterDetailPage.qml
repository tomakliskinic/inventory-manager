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
    property var expandedContainers: ({})

    readonly property bool isFiltering: searchText !== "" || filterType >= 0 || filterSource >= 0

    function isContainerExpanded(id) {
        return expandedContainers[id] === true
    }

    function toggleContainerExpansion(id) {
        const next = Object.assign({}, expandedContainers)
        if (next[id]) delete next[id]
        else next[id] = true
        expandedContainers = next
    }

    function isAncestorChainExpanded(item) {
        let parentId = item.parent_inventory_item_id
        while (parentId) {
            if (!isContainerExpanded(parentId)) return false
            const parent = inventoryItems.find(i => i.id === parentId)
            parentId = parent ? parent.parent_inventory_item_id : null
        }
        return true
    }

    function costInCopper(text) {
        if (!text) return Number.POSITIVE_INFINITY
        const m = String(text).match(/^\s*([\d,]+)\s*([A-Z]{2})/)
        if (!m) return Number.POSITIVE_INFINITY
        const amount = parseInt(m[1].replace(/,/g, ""), 10)
        if (isNaN(amount)) return Number.POSITIVE_INFINITY
        const mult = { CP: 1, SP: 10, EP: 50, GP: 100, PP: 1000 }[m[2]]
        return mult === undefined ? Number.POSITIVE_INFINITY : amount * mult
    }

    function formatCopper(cp) {
        if (cp <= 0) return qsTr("—")
        const parts = []
        let rem = cp
        const pp = Math.floor(rem / 1000); rem -= pp * 1000
        const gp = Math.floor(rem / 100);  rem -= gp * 100
        const sp = Math.floor(rem / 10);   rem -= sp * 10
        if (pp) parts.push(pp + " PP")
        if (gp) parts.push(gp + " GP")
        if (sp) parts.push(sp + " SP")
        if (rem) parts.push(rem + " CP")
        return parts.join(", ")
    }

    readonly property int inventoryValueCopper: {
        let total = 0
        for (const item of inventoryItems) {
            const cp = costInCopper(item.item_cost)
            if (isFinite(cp)) total += cp * item.quantity
        }
        return total
    }

    readonly property var childrenByParent: {
        const map = {}
        for (const item of inventoryItems) {
            const p = item.parent_inventory_item_id || 0
            if (!map[p]) map[p] = []
            map[p].push(item)
        }
        return map
    }

    function aggregateWeight(item) {
        const fw = item.fixed_weight
        if (isFinite(fw) && fw > 0)
            return fw * item.quantity
        let total = (item.weight_lb || 0) * item.quantity
        const kids = childrenByParent[item.id] || []
        for (const kid of kids)
            total += aggregateWeight(kid)
        return total
    }

    function aggregateCost(item) {
        let total = 0
        let anyKnown = false
        const cp = costInCopper(item.item_cost)
        if (isFinite(cp)) {
            total += cp * item.quantity
            anyKnown = true
        }
        const kids = childrenByParent[item.id] || []
        for (const kid of kids) {
            const sub = aggregateCost(kid)
            if (isFinite(sub)) {
                total += sub
                anyKnown = true
            }
        }
        return anyKnown ? total : Number.POSITIVE_INFINITY
    }

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
        } else {
            result = result.filter(i => isAncestorChainExpanded(i))
        }

        if (sortField > 0) {
            let cmp
            if (sortField === 1)
                cmp = (a, b) =>
                    (a.custom_name || a.item_name).localeCompare(b.custom_name || b.item_name)
            else if (sortField === 2)
                cmp = (a, b) => aggregateWeight(a) - aggregateWeight(b)
            else if (sortField === 3)
                cmp = (a, b) => a.quantity - b.quantity
            else if (sortField === 4)
                cmp = (a, b) => (a.created_at || "").localeCompare(b.created_at || "")
            else
                cmp = (a, b) => aggregateCost(a) - aggregateCost(b)

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
        id: detailToolBar
        readonly property bool isNarrow: width < 480

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
                visible: !detailToolBar.isNarrow
                text: qsTr("Edit")
                onClicked: root.editCharacterRequested(root.character)
            }
            ToolButton {
                visible: !detailToolBar.isNarrow
                text: qsTr("Export")
                onClicked: root.exportRequested(root.character.id)
            }
            ToolButton {
                visible: !detailToolBar.isNarrow
                text: qsTr("Delete")
                onClicked: root.deleteCharacterRequested(root.character)
            }
            ToolButton {
                id: detailOverflowBtn
                visible: detailToolBar.isNarrow
                text: "…"
                font.pixelSize: 20
                onClicked: detailOverflow.open()
                Menu {
                    id: detailOverflow
                    x: detailOverflowBtn.width - width
                    y: detailOverflowBtn.height
                    MenuItem {
                        text: qsTr("Edit")
                        onTriggered: root.editCharacterRequested(root.character)
                    }
                    MenuItem {
                        text: qsTr("Export")
                        onTriggered: root.exportRequested(root.character.id)
                    }
                    MenuItem {
                        text: qsTr("Delete")
                        onTriggered: root.deleteCharacterRequested(root.character)
                    }
                }
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

                    Label { text: qsTr("Inventory value"); font.bold: true }
                    Label {
                        text: root.formatCopper(root.inventoryValueCopper)
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
                                { id: 4, name: qsTr("Date added") },
                                { id: 5, name: qsTr("Cost") }
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
                        delegate: ItemDelegate {
                            id: rowDelegate
                            Layout.fillWidth: true
                            padding: 4
                            hoverEnabled: modelData.is_container
                            onClicked: {
                                if (modelData.is_container)
                                    root.toggleContainerExpansion(modelData.id)
                            }
                            background: Rectangle {
                                color: {
                                    if (!modelData.is_container) return "transparent"
                                    if (rowDelegate.pressed) return Qt.rgba(0, 0, 0, 0.12)
                                    if (rowDelegate.hovered) return Qt.rgba(0, 0, 0, 0.06)
                                    return "transparent"
                                }
                            }

                            contentItem: RowLayout {
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
                                    text: {
                                        const own = (modelData.weight_lb * modelData.quantity).toFixed(1)
                                        if (!modelData.is_container) return qsTr("%1 lb").arg(own)
                                        const agg = root.aggregateWeight(modelData).toFixed(1)
                                        if (agg === own) return qsTr("%1 lb").arg(own)
                                        return qsTr("%1 (%2) lb").arg(own).arg(agg)
                                    }
                                    opacity: 0.7
                                    Layout.preferredWidth: 90
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
