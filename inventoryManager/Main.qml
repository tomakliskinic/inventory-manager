import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import inventoryManager

ApplicationWindow {
    id: window
    width: 640
    height: 480
    visible: true
    title: qsTr("Inventory Manager")

    Material.theme: Material.Light
    Material.accent: Material.Indigo

    property var characters: []

    Component.onCompleted: refresh()

    function refresh() {
        characters = DB.getAllCharacters()
    }

    function refreshCurrentDetail() {
        if (stack.currentItem && stack.currentItem.refresh)
            stack.currentItem.refresh()
    }

    function notifyError(msg) {
        errorBanner.message = msg
        errorBanner.isError = true
        errorBanner.open()
        errorTimer.restart()
    }

    function notifyInfo(msg) {
        errorBanner.message = msg
        errorBanner.isError = false
        errorBanner.open()
        errorTimer.restart()
    }

    StackView {
        id: stack
        anchors.fill: parent
        anchors.bottomMargin: inputPanel.active ? inputPanel.height : 0
        initialItem: listPageComponent
    }

    Shortcut {
        sequence: "Escape"
        enabled: stack.depth > 1
                 && !characterDialog.opened
                 && !deleteConfirm.opened
                 && !coinsDialog.opened
                 && !addItemDialog.opened
                 && !itemEditDialog.opened
                 && !itemRemoveSimpleConfirm.opened
                 && !itemRemoveContainerDialog.opened
                 && !itemMoveDialog.opened
                 && !itemDefinitionViewDialog.opened
                 && !itemDefinitionEditDialog.opened
                 && !catalogDeleteConfirm.opened
        onActivated: stack.pop()
    }

    Component {
        id: listPageComponent

        Page {
            header: ToolBar {
                RowLayout {
                    anchors.fill: parent
                    Item { Layout.preferredWidth: 8 }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Characters")
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                    }
                    ToolButton {
                        text: qsTr("Items")
                        onClicked: stack.push(itemCatalogPageComponent)
                    }
                    ToolButton {
                        text: qsTr("Import")
                        onClicked: importFileDialog.open()
                    }
                    ToolButton {
                        text: qsTr("Export all")
                        enabled: characters.length > 0
                        onClicked: {
                            exportFileDialog.targetCharacterId = -1
                            exportFileDialog.open()
                        }
                    }
                }
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.bottomMargin: addButton.height + 32
                visible: characters.length > 0
                model: characters

                delegate: ItemDelegate {
                    width: ListView.view.width

                    contentItem: RowLayout {
                        Label {
                            text: modelData.name
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        ToolButton {
                            text: "⋮"
                            font.pixelSize: 18
                            onClicked: {
                                rowMenu.character = modelData
                                rowMenu.popup()
                            }
                        }
                    }

                    onClicked: stack.push(detailPageComponent, { "character": modelData })
                }
            }

            Menu {
                id: rowMenu
                property var character: null

                MenuItem {
                    text: qsTr("Edit")
                    onTriggered: characterDialog.openEdit(rowMenu.character)
                }
                MenuItem {
                    text: qsTr("Delete")
                    onTriggered: {
                        deleteConfirm.character = rowMenu.character
                        deleteConfirm.open()
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: characters.length === 0
                text: qsTr("No characters yet")
                font.pixelSize: 18
                opacity: 0.6
            }

            RoundButton {
                id: addButton
                text: "+"
                font.pixelSize: 24
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 16
                onClicked: characterDialog.openCreate()
            }
        }
    }

    Component {
        id: itemCatalogPageComponent

        Page {
            id: catalogPage
            property var allItems: []
            property string searchText: ""
            property int filterType: -1
            property int filterSource: -1
            property bool searchInDescription: false

            readonly property var filteredItems: {
                let result = allItems
                if (searchText) {
                    const needle = searchText
                    const includeDesc = searchInDescription
                    result = result.filter(i => {
                        if ((i.name || "").toLowerCase().includes(needle)) return true
                        if (includeDesc && (i.description || "").toLowerCase().includes(needle)) return true
                        return false
                    })
                }
                if (filterType >= 0)
                    result = result.filter(i => i.item_type === filterType)
                if (filterSource >= 0)
                    result = result.filter(i => i.source === filterSource)
                return result
            }

            function refresh() {
                allItems = DB.getItemDefinitions()
            }

            Component.onCompleted: refresh()

            header: ToolBar {
                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    ToolButton {
                        text: "←"
                        font.pixelSize: 20
                        onClicked: stack.pop()
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Item Catalog")
                        font.pixelSize: 18
                    }
                    ToolButton {
                        text: qsTr("+ Add")
                        onClicked: itemDefinitionEditDialog.openCreate()
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    TextField {
                        Layout.fillWidth: true
                        placeholderText: qsTr("Search…")
                        onTextChanged: catalogPage.searchText = text.trim().toLowerCase()
                    }
                    CheckBox {
                        text: qsTr("Description")
                        checked: catalogPage.searchInDescription
                        onToggled: catalogPage.searchInDescription = checked
                    }
                    ComboBox {
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
                        onActivated: catalogPage.filterType = currentValue
                    }
                    ComboBox {
                        Layout.preferredWidth: 130
                        textRole: "name"
                        valueRole: "id"
                        model: [
                            { id: -1, name: qsTr("All sources") },
                            { id: Enums.ItemSource.SRD, name: qsTr("SRD") },
                            { id: Enums.ItemSource.Homebrew, name: qsTr("Homebrew") }
                        ]
                        onActivated: catalogPage.filterSource = currentValue
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: catalogPage.filteredItems.length === 0
                    text: catalogPage.allItems.length === 0
                        ? qsTr("No items in catalog")
                        : qsTr("No items match.")
                    opacity: 0.5
                    horizontalAlignment: Text.AlignHCenter
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: catalogPage.filteredItems
                    spacing: 2

                    delegate: ItemDelegate {
                        width: ListView.view.width

                        contentItem: RowLayout {
                            Label {
                                text: (modelData.is_container ? "📦 " : "") + modelData.name
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Label {
                                text: ["Weapon", "Armor", "Gear", "Tool", "Magic"][modelData.item_type] || ""
                                opacity: 0.6
                                Layout.preferredWidth: 70
                            }
                            Label {
                                text: qsTr("%1 lb").arg(modelData.weight_lb.toFixed(1))
                                opacity: 0.6
                                Layout.preferredWidth: 60
                                horizontalAlignment: Text.AlignRight
                            }
                            Label {
                                text: modelData.source === Enums.ItemSource.Homebrew ? "🛠" : ""
                                font.pixelSize: 14
                                Layout.preferredWidth: 24
                                horizontalAlignment: Text.AlignHCenter
                            }
                            ToolButton {
                                text: "⋮"
                                font.pixelSize: 16
                                visible: modelData.source === Enums.ItemSource.Homebrew
                                onClicked: {
                                    catalogRowMenu.item = modelData
                                    catalogRowMenu.popup()
                                }
                            }
                        }

                        onClicked: itemDefinitionViewDialog.openFor(modelData)
                    }
                }

                Menu {
                    id: catalogRowMenu
                    property var item: null

                    MenuItem {
                        text: qsTr("Edit")
                        onTriggered: itemDefinitionEditDialog.openEdit(catalogRowMenu.item)
                    }
                    MenuItem {
                        text: qsTr("Delete")
                        onTriggered: {
                            catalogDeleteConfirm.item = catalogRowMenu.item
                            catalogDeleteConfirm.open()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: detailPageComponent

        Page {
            id: detailPage
            property var character
            property var coins: ({})
            property real totalWeight: 0
            property real coinWeight: 0
            property real carryingCapacity: 0
            property var inventoryItems: []

            property string searchText: ""
            property int filterType: -1
            property int sortField: 0
            property bool sortAscending: true

            readonly property bool isFiltering: searchText !== "" || filterType >= 0

            readonly property var filteredItems: {
                let result = inventoryItems

                if (isFiltering) {
                    const matches = new Set()
                    for (const item of inventoryItems) {
                        const matchesSearch = !searchText
                            || (item.item_name || "").toLowerCase().includes(searchText)
                            || (item.custom_name || "").toLowerCase().includes(searchText)
                            || (item.notes || "").toLowerCase().includes(searchText)
                        const matchesType = filterType < 0 || item.item_type === filterType
                        if (matchesSearch && matchesType)
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
                        onClicked: stack.pop()
                    }
                    Label {
                        text: detailPage.character ? detailPage.character.name : ""
                        Layout.fillWidth: true
                        elide: Label.ElideRight
                        font.pixelSize: 18
                    }
                    ToolButton {
                        text: qsTr("Edit")
                        onClicked: characterDialog.openEdit(detailPage.character)
                    }
                    ToolButton {
                        text: qsTr("Export")
                        onClicked: {
                            exportFileDialog.targetCharacterId = detailPage.character.id
                            exportFileDialog.open()
                        }
                    }
                    ToolButton {
                        text: qsTr("Delete")
                        onClicked: {
                            deleteConfirm.character = detailPage.character
                            deleteConfirm.open()
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
                            Label { text: detailPage.character ? (detailPage.character.race || "—") : "" }

                            Label { text: qsTr("Class"); font.bold: true }
                            Label { text: detailPage.character ? (detailPage.character.class || "—") : "" }

                            Label { text: qsTr("Level"); font.bold: true }
                            Label { text: detailPage.character ? detailPage.character.level : "" }

                            Label { text: qsTr("Strength"); font.bold: true }
                            Label { text: detailPage.character ? detailPage.character.strength : "" }

                            Label { text: qsTr("Size"); font.bold: true }
                            Label {
                                text: detailPage.character
                                    ? DB.creatureSizeNames()[detailPage.character.size] || "—"
                                    : ""
                            }
                        }
                    }

                    Frame {
                        Layout.fillWidth: true
                        Layout.margins: 16
                        visible: detailPage.character && detailPage.character.notes

                        ColumnLayout {
                            anchors.fill: parent

                            Label { text: qsTr("Notes"); font.bold: true }
                            Label {
                                text: detailPage.character ? (detailPage.character.notes || "") : ""
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
                                    onClicked: coinsDialog.openFor(detailPage.character.id)
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

                                Label { text: detailPage.coins.cp || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                                Label { text: detailPage.coins.sp || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                                Label { text: detailPage.coins.ep || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                                Label { text: detailPage.coins.gp || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
                                Label { text: detailPage.coins.pp || 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 16 }
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
                                    .arg(detailPage.totalWeight.toFixed(1))
                                    .arg(detailPage.carryingCapacity.toFixed(0))
                            }
                            Label {
                                text: qsTr("Coin weight: %1 lbs").arg(detailPage.coinWeight.toFixed(2))
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
                                    width: parent.width * (detailPage.carryingCapacity > 0
                                        ? Math.min(detailPage.totalWeight / detailPage.carryingCapacity, 1)
                                        : 0)
                                    color: window.Material.accent
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
                                    onClicked: addItemDialog.openFor(detailPage.character.id)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: detailPage.inventoryItems.length > 0

                                TextField {
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Search…")
                                    onTextChanged: detailPage.searchText = text.trim().toLowerCase()
                                }
                                ComboBox {
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
                                    onActivated: detailPage.filterType = currentValue
                                }
                                ComboBox {
                                    Layout.preferredWidth: 140
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
                                        detailPage.sortField = currentValue
                                        detailPage.sortAscending = currentValue === 1
                                    }
                                }
                                ToolButton {
                                    text: detailPage.sortAscending ? "↑" : "↓"
                                    enabled: detailPage.sortField > 0
                                    onClicked: detailPage.sortAscending = !detailPage.sortAscending
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: detailPage.inventoryItems.length === 0
                                text: qsTr("No items")
                                opacity: 0.5
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: detailPage.inventoryItems.length > 0
                                         && detailPage.filteredItems.length === 0
                                text: qsTr("No items match.")
                                opacity: 0.5
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Repeater {
                                model: detailPage.filteredItems
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
                                        text: "⋮"
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
                                    onTriggered: itemEditDialog.openFor(inventoryRowMenu.item)
                                }
                                MenuItem {
                                    text: qsTr("Move")
                                    onTriggered: itemMoveDialog.openFor(inventoryRowMenu.item, detailPage.character.id)
                                }
                                MenuItem {
                                    text: qsTr("Remove")
                                    onTriggered: {
                                        const it = inventoryRowMenu.item
                                        if (it.is_container && DB.getContainerContents(it.id).length > 0) {
                                            itemRemoveContainerDialog.openFor(it, detailPage.character.id)
                                        } else {
                                            itemRemoveSimpleConfirm.item = it
                                            itemRemoveSimpleConfirm.open()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: characterDialog
        property int editingId: -1

        title: editingId === -1 ? qsTr("New Character") : qsTr("Edit Character")
        modal: true
        anchors.centerIn: parent
        width: 480
        height: Math.min(window.height - 60, 560)
        standardButtons: Dialog.Ok | Dialog.Cancel

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            GridLayout {
                width: characterDialog.availableWidth - 20
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label { text: qsTr("Name") }
                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    onAccepted: characterDialog.accept()
                }

                Label { text: qsTr("Race") }
                TextField {
                    id: raceField
                    Layout.fillWidth: true
                }

                Label { text: qsTr("Class") }
                TextField {
                    id: classField
                    Layout.fillWidth: true
                }

                Label { text: qsTr("Level") }
                SpinBox {
                    id: levelField
                    from: 1; to: 20; value: 1
                    Layout.fillWidth: true
                    editable: true
                }

                Label { text: qsTr("Strength") }
                SpinBox {
                    id: strengthField
                    from: 1; to: 30; value: 10
                    Layout.fillWidth: true
                    editable: true
                }

                Label { text: qsTr("Size") }
                ComboBox {
                    id: sizeField
                    Layout.fillWidth: true
                    model: DB.creatureSizeNames()
                    currentIndex: Enums.CreatureSize.Medium
                }

                Label {
                    text: qsTr("Notes")
                    Layout.alignment: Qt.AlignTop
                }
                ScrollView {
                    id: notesScroll
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
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
                        id: notesField
                        wrapMode: TextArea.Wrap
                        onCursorRectangleChanged: notesScroll.ensureCursorVisible(cursorRectangle)
                    }
                }
            }
        }

        function resetForm() {
            editingId = -1
            nameField.text = ""
            raceField.text = ""
            classField.text = ""
            levelField.value = 1
            strengthField.value = 10
            sizeField.currentIndex = Enums.CreatureSize.Medium
            notesField.text = ""
        }

        function openCreate() {
            resetForm()
            open()
        }

        function openEdit(character) {
            editingId = character.id
            nameField.text = character.name || ""
            raceField.text = character.race || ""
            classField.text = character.class || ""
            levelField.value = character.level || 1
            strengthField.value = character.strength || 10
            sizeField.currentIndex = character.size !== undefined ? character.size : Enums.CreatureSize.Medium
            notesField.text = character.notes || ""
            open()
        }

        onAccepted: {
            const name = nameField.text.trim()
            if (!name) {
                resetForm()
                return
            }
            const data = {
                "name": name,
                "race": raceField.text.trim(),
                "class": classField.text.trim(),
                "level": levelField.value,
                "strength": strengthField.value,
                "size": sizeField.currentIndex,
                "notes": notesField.text.trim()
            }
            if (editingId === -1)
                DB.createCharacter(data)
            else
                DB.updateCharacter(editingId, data)
            refresh()
            refreshCurrentDetail()
            resetForm()
        }
        onRejected: resetForm()
    }

    Dialog {
        id: deleteConfirm
        property var character: null

        title: qsTr("Delete Character?")
        modal: true
        anchors.centerIn: parent
        width: 360
        standardButtons: Dialog.Yes | Dialog.No

        Label {
            anchors.fill: parent
            text: deleteConfirm.character
                ? qsTr("Delete \"%1\"? This cannot be undone.").arg(deleteConfirm.character.name)
                : ""
            wrapMode: Text.Wrap
        }

        onAccepted: {
            if (character) {
                const id = character.id
                DB.deleteCharacter(id)
                refresh()
                if (stack.currentItem && stack.currentItem.character
                        && stack.currentItem.character.id === id)
                    stack.pop()
            }
            character = null
        }
        onRejected: character = null
    }

    Dialog {
        id: coinsDialog
        property int characterId: -1

        title: qsTr("Edit Coins")
        modal: true
        anchors.centerIn: parent
        width: 360
        standardButtons: Dialog.Ok | Dialog.Cancel

        GridLayout {
            anchors.fill: parent
            columns: 2
            columnSpacing: 12
            rowSpacing: 8

            Label { text: qsTr("CP") }
            SpinBox { id: cpField; Layout.fillWidth: true; from: 0; to: 9999999; editable: true }
            Label { text: qsTr("SP") }
            SpinBox { id: spField; Layout.fillWidth: true; from: 0; to: 9999999; editable: true }
            Label { text: qsTr("EP") }
            SpinBox { id: epField; Layout.fillWidth: true; from: 0; to: 9999999; editable: true }
            Label { text: qsTr("GP") }
            SpinBox { id: gpField; Layout.fillWidth: true; from: 0; to: 9999999; editable: true }
            Label { text: qsTr("PP") }
            SpinBox { id: ppField; Layout.fillWidth: true; from: 0; to: 9999999; editable: true }
        }

        function openFor(charId) {
            characterId = charId
            const c = DB.getCoins(charId)
            cpField.value = c.cp || 0
            spField.value = c.sp || 0
            epField.value = c.ep || 0
            gpField.value = c.gp || 0
            ppField.value = c.pp || 0
            open()
        }

        onAccepted: {
            if (characterId > 0) {
                DB.updateCoins(characterId, {
                    "cp": cpField.value,
                    "sp": spField.value,
                    "ep": epField.value,
                    "gp": gpField.value,
                    "pp": ppField.value
                })
                refreshCurrentDetail()
            }
            characterId = -1
        }
        onRejected: characterId = -1
    }

    Dialog {
        id: addItemDialog
        property int characterId: -1
        property var itemDefs: []
        property var containerOptions: []
        property string itemSearchText: ""
        property int itemFilterType: -1

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
        anchors.centerIn: parent
        width: 460
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
                        addItemDialog.itemSearchText = text.trim().toLowerCase()
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
                        addItemDialog.itemFilterType = currentValue
                        itemCombo.currentIndex = 0
                    }
                }
            }

            Label { text: qsTr("Item") }
            ComboBox {
                id: itemCombo
                Layout.fillWidth: true
                model: addItemDialog.filteredItemDefs
                textRole: "name"
                valueRole: "id"
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
                model: addItemDialog.containerOptions
                textRole: "name"
                valueRole: "id"
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
                    notifyError(DB.lastError() || qsTr("Couldn't add item."))
                refreshCurrentDetail()
            }
            characterId = -1
        }
        onRejected: characterId = -1
    }

    Dialog {
        id: itemEditDialog
        property int itemId: -1

        title: qsTr("Edit Item")
        modal: true
        anchors.centerIn: parent
        width: 480
        height: Math.min(window.height - 60, 460)
        standardButtons: Dialog.Ok | Dialog.Cancel

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            GridLayout {
                width: itemEditDialog.availableWidth - 20
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                Label { text: qsTr("Quantity") }
                SpinBox {
                    id: itemQtyField
                    Layout.fillWidth: true
                    from: 1; to: 999
                    editable: true
                }

                Label { text: qsTr("Custom name") }
                TextField {
                    id: itemNameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("(optional)")
                }

                Label { text: qsTr("Equipped") }
                CheckBox {
                    id: itemEquippedField
                }

                Label {
                    text: qsTr("Notes")
                    Layout.alignment: Qt.AlignTop
                }
                ScrollView {
                    id: itemNotesScroll
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
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
                        id: itemNotesField
                        wrapMode: TextArea.Wrap
                        onCursorRectangleChanged: itemNotesScroll.ensureCursorVisible(cursorRectangle)
                    }
                }
            }
        }

        function openFor(item) {
            itemId = item.id
            itemQtyField.value = item.quantity || 1
            itemNameField.text = item.custom_name || ""
            itemNotesField.text = item.notes || ""
            itemEquippedField.checked = !!item.is_equipped
            open()
        }

        onAccepted: {
            if (itemId > 0) {
                const ok = DB.updateInventoryItem(itemId, {
                    "quantity": itemQtyField.value,
                    "custom_name": itemNameField.text.trim() || null,
                    "notes": itemNotesField.text.trim() || null,
                    "is_equipped": itemEquippedField.checked ? 1 : 0
                })
                if (!ok)
                    notifyError(DB.lastError() || qsTr("Couldn't update item."))
                refreshCurrentDetail()
            }
            itemId = -1
        }
        onRejected: itemId = -1
    }

    Dialog {
        id: itemRemoveSimpleConfirm
        property var item: null

        title: qsTr("Remove Item?")
        modal: true
        anchors.centerIn: parent
        width: 360
        standardButtons: Dialog.Yes | Dialog.No

        Label {
            anchors.fill: parent
            text: itemRemoveSimpleConfirm.item
                ? qsTr("Remove \"%1\"?").arg(itemRemoveSimpleConfirm.item.custom_name
                                              || itemRemoveSimpleConfirm.item.item_name)
                : ""
            wrapMode: Text.Wrap
        }

        onAccepted: {
            if (item) {
                const ok = DB.removeInventoryItem(item.id)
                if (!ok)
                    notifyError(DB.lastError() || qsTr("Couldn't remove item."))
                refreshCurrentDetail()
            }
            item = null
        }
        onRejected: item = null
    }

    Dialog {
        id: itemRemoveContainerDialog
        property var item: null
        property var destinationOptions: []

        title: qsTr("Remove Container?")
        modal: true
        anchors.centerIn: parent
        width: 460

        function openFor(itm, charId) {
            item = itm

            const allItems = DB.getInventoryTree(charId)
            const excluded = new Set([itm.id])
            let changed = true
            while (changed) {
                changed = false
                for (const i of allItems) {
                    if (excluded.has(i.parent_inventory_item_id) && !excluded.has(i.id)) {
                        excluded.add(i.id)
                        changed = true
                    }
                }
            }

            const containers = allItems.filter(i => i.is_container && !excluded.has(i.id))
            const opts = []
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
            destinationOptions = opts
            moveContentsCombo.currentIndex = 0
            open()
        }

        function applyMode(mode, destId) {
            if (item) {
                const ok = DB.removeInventoryItem(item.id, mode, destId !== undefined ? destId : -1)
                if (!ok)
                    notifyError(DB.lastError() || qsTr("Couldn't remove item."))
                refreshCurrentDetail()
            }
            item = null
            close()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Label {
                text: itemRemoveContainerDialog.item
                    ? qsTr("\"%1\" contains items. What should happen to them?")
                        .arg(itemRemoveContainerDialog.item.custom_name
                             || itemRemoveContainerDialog.item.item_name)
                    : ""
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Spill contents out")
                Layout.fillWidth: true
                onClicked: itemRemoveContainerDialog.applyMode(Enums.RemovalMode.SpillToParent)
            }
            Button {
                text: qsTr("Delete with all contents")
                Layout.fillWidth: true
                onClicked: itemRemoveContainerDialog.applyMode(Enums.RemovalMode.DeleteAll)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: itemRemoveContainerDialog.destinationOptions.length > 0

                ComboBox {
                    id: moveContentsCombo
                    Layout.fillWidth: true
                    model: itemRemoveContainerDialog.destinationOptions
                    textRole: "name"
                    valueRole: "id"
                }
                Button {
                    text: qsTr("Move to")
                    enabled: moveContentsCombo.currentValue !== undefined
                             && moveContentsCombo.currentValue > 0
                    onClicked: itemRemoveContainerDialog.applyMode(
                        Enums.RemovalMode.MoveToContainer, moveContentsCombo.currentValue)
                }
            }

            Button {
                text: qsTr("Cancel")
                Layout.fillWidth: true
                flat: true
                onClicked: {
                    itemRemoveContainerDialog.item = null
                    itemRemoveContainerDialog.close()
                }
            }
        }
    }

    Dialog {
        id: itemMoveDialog
        property var item: null
        property int characterId: -1
        property var destinationOptions: []

        title: qsTr("Move Item")
        modal: true
        anchors.centerIn: parent
        width: 420
        standardButtons: Dialog.Ok | Dialog.Cancel

        GridLayout {
            anchors.fill: parent
            columns: 2
            columnSpacing: 12
            rowSpacing: 8

            Label { text: qsTr("Destination") }
            ComboBox {
                id: moveDestCombo
                Layout.fillWidth: true
                model: itemMoveDialog.destinationOptions
                textRole: "name"
                valueRole: "id"
            }
        }

        function openFor(itm, charId) {
            item = itm
            characterId = charId

            const allItems = DB.getInventoryTree(charId)

            const excluded = new Set([itm.id])
            let changed = true
            while (changed) {
                changed = false
                for (const i of allItems) {
                    if (excluded.has(i.parent_inventory_item_id) && !excluded.has(i.id)) {
                        excluded.add(i.id)
                        changed = true
                    }
                }
            }

            const containers = allItems.filter(i => i.is_container && !excluded.has(i.id))
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
            destinationOptions = opts

            const currentParent = itm.parent_inventory_item_id || -1
            const idx = opts.findIndex(o => o.id === currentParent)
            moveDestCombo.currentIndex = idx >= 0 ? idx : 0

            open()
        }

        onAccepted: {
            if (item && moveDestCombo.currentValue !== undefined) {
                const ok = DB.updateInventoryItem(item.id, {
                    "parent_inventory_item_id": moveDestCombo.currentValue
                })
                if (!ok)
                    notifyError(DB.lastError() || qsTr("Couldn't move item."))
                refreshCurrentDetail()
            }
            item = null
            characterId = -1
        }
        onRejected: {
            item = null
            characterId = -1
        }
    }

    Dialog {
        id: itemDefinitionViewDialog
        property var item: null
        property var weaponDetails: ({})

        readonly property bool isWeapon: !!item && item.item_type === Enums.ItemType.Weapon

        function openFor(it) {
            item = it
            if (it && it.item_type === Enums.ItemType.Weapon)
                weaponDetails = DB.getWeaponDetails(it.id)
            else
                weaponDetails = ({})
            open()
        }

        title: item ? item.name : ""
        modal: true
        anchors.centerIn: parent
        width: 480
        height: Math.min(window.height - 60, 600)
        standardButtons: Dialog.Close

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            GridLayout {
                width: itemDefinitionViewDialog.availableWidth - 20
                columns: 2
                columnSpacing: 16
                rowSpacing: 8

                Label { text: qsTr("Type"); font.bold: true }
                Label {
                    text: itemDefinitionViewDialog.item
                        ? (["Weapon", "Armor", "Gear", "Tool", "Magic"][itemDefinitionViewDialog.item.item_type] || "—")
                        : ""
                }

                Label { text: qsTr("Weight"); font.bold: true }
                Label {
                    text: itemDefinitionViewDialog.item
                        ? qsTr("%1 lb").arg(itemDefinitionViewDialog.item.weight_lb.toFixed(1))
                        : ""
                }

                Label {
                    text: qsTr("Cost"); font.bold: true
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.cost
                }
                Label {
                    text: itemDefinitionViewDialog.item ? (itemDefinitionViewDialog.item.cost || "") : ""
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.cost
                }

                Label {
                    text: qsTr("Rarity"); font.bold: true
                    visible: itemDefinitionViewDialog.item && Number.isFinite(itemDefinitionViewDialog.item.rarity)
                }
                Label {
                    text: itemDefinitionViewDialog.item
                        ? (["Common", "Uncommon", "Rare", "Very Rare", "Legendary", "Artifact"][itemDefinitionViewDialog.item.rarity] || "")
                        : ""
                    visible: itemDefinitionViewDialog.item && Number.isFinite(itemDefinitionViewDialog.item.rarity)
                }

                Label {
                    text: qsTr("Attunement"); font.bold: true
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.requires_attunement
                }
                Label {
                    text: qsTr("Required")
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.requires_attunement
                }

                Label {
                    text: qsTr("Container"); font.bold: true
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.is_container
                }
                Label {
                    text: qsTr("Yes")
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.is_container
                }

                Label {
                    text: qsTr("Capacity"); font.bold: true
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.is_container
                             && Number.isFinite(itemDefinitionViewDialog.item.container_weight_capacity)
                             && itemDefinitionViewDialog.item.container_weight_capacity > 0
                }
                Label {
                    text: itemDefinitionViewDialog.item && Number.isFinite(itemDefinitionViewDialog.item.container_weight_capacity)
                        ? qsTr("%1 lb").arg(itemDefinitionViewDialog.item.container_weight_capacity.toFixed(0))
                        : ""
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.is_container
                             && Number.isFinite(itemDefinitionViewDialog.item.container_weight_capacity)
                             && itemDefinitionViewDialog.item.container_weight_capacity > 0
                }

                Label {
                    text: qsTr("Fixed weight"); font.bold: true
                    visible: itemDefinitionViewDialog.item
                             && Number.isFinite(itemDefinitionViewDialog.item.fixed_weight)
                             && itemDefinitionViewDialog.item.fixed_weight > 0
                }
                Label {
                    text: itemDefinitionViewDialog.item && Number.isFinite(itemDefinitionViewDialog.item.fixed_weight)
                        ? qsTr("%1 lb").arg(itemDefinitionViewDialog.item.fixed_weight.toFixed(1))
                        : ""
                    visible: itemDefinitionViewDialog.item
                             && Number.isFinite(itemDefinitionViewDialog.item.fixed_weight)
                             && itemDefinitionViewDialog.item.fixed_weight > 0
                }

                Label { text: qsTr("Source"); font.bold: true }
                Label {
                    text: itemDefinitionViewDialog.item
                        ? (itemDefinitionViewDialog.item.source === Enums.ItemSource.Homebrew ? qsTr("Homebrew") : qsTr("SRD"))
                        : ""
                }

                Label {
                    text: qsTr("Category"); font.bold: true
                    visible: itemDefinitionViewDialog.isWeapon
                             && Number.isFinite(itemDefinitionViewDialog.weaponDetails.category)
                }
                Label {
                    text: itemDefinitionViewDialog.isWeapon
                        ? (["Simple", "Martial"][itemDefinitionViewDialog.weaponDetails.category] || "")
                        : ""
                    visible: itemDefinitionViewDialog.isWeapon
                             && Number.isFinite(itemDefinitionViewDialog.weaponDetails.category)
                }

                Label {
                    text: qsTr("Range"); font.bold: true
                    visible: itemDefinitionViewDialog.isWeapon
                             && Number.isFinite(itemDefinitionViewDialog.weaponDetails.range_type)
                }
                Label {
                    text: itemDefinitionViewDialog.isWeapon
                        ? (["Melee", "Ranged"][itemDefinitionViewDialog.weaponDetails.range_type] || "")
                        : ""
                    visible: itemDefinitionViewDialog.isWeapon
                             && Number.isFinite(itemDefinitionViewDialog.weaponDetails.range_type)
                }

                Label {
                    text: qsTr("Damage"); font.bold: true
                    visible: itemDefinitionViewDialog.isWeapon
                             && !!itemDefinitionViewDialog.weaponDetails.damage_dice
                }
                Label {
                    text: {
                        if (!itemDefinitionViewDialog.isWeapon) return ""
                        const wd = itemDefinitionViewDialog.weaponDetails
                        const damageTypes = ["Bludgeoning", "Piercing", "Slashing", "Acid", "Cold", "Fire",
                            "Force", "Lightning", "Necrotic", "Poison", "Psychic", "Radiant", "Thunder"]
                        const dt = damageTypes[wd.damage_type] || ""
                        return (wd.damage_dice || "") + (dt ? " " + dt : "")
                    }
                    visible: itemDefinitionViewDialog.isWeapon
                             && !!itemDefinitionViewDialog.weaponDetails.damage_dice
                }

                Label {
                    text: qsTr("Properties"); font.bold: true
                    Layout.alignment: Qt.AlignTop
                    visible: itemDefinitionViewDialog.isWeapon
                             && !!itemDefinitionViewDialog.weaponDetails.properties
                             && itemDefinitionViewDialog.weaponDetails.properties !== "[]"
                }
                Label {
                    text: {
                        if (!itemDefinitionViewDialog.isWeapon) return ""
                        try {
                            const arr = JSON.parse(itemDefinitionViewDialog.weaponDetails.properties || "[]")
                            return arr.join(", ")
                        } catch (e) {
                            return ""
                        }
                    }
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    visible: itemDefinitionViewDialog.isWeapon
                             && !!itemDefinitionViewDialog.weaponDetails.properties
                             && itemDefinitionViewDialog.weaponDetails.properties !== "[]"
                }

                Label {
                    text: qsTr("Mastery"); font.bold: true
                    visible: itemDefinitionViewDialog.isWeapon
                             && !!itemDefinitionViewDialog.weaponDetails.mastery
                }
                Label {
                    text: itemDefinitionViewDialog.isWeapon
                        ? (itemDefinitionViewDialog.weaponDetails.mastery || "")
                        : ""
                    visible: itemDefinitionViewDialog.isWeapon
                             && !!itemDefinitionViewDialog.weaponDetails.mastery
                }

                Label {
                    text: qsTr("Ammunition"); font.bold: true
                    visible: itemDefinitionViewDialog.isWeapon
                             && !!itemDefinitionViewDialog.weaponDetails.ammunition_type
                }
                Label {
                    text: itemDefinitionViewDialog.isWeapon
                        ? (itemDefinitionViewDialog.weaponDetails.ammunition_type || "")
                        : ""
                    visible: itemDefinitionViewDialog.isWeapon
                             && !!itemDefinitionViewDialog.weaponDetails.ammunition_type
                }

                Label {
                    text: qsTr("Description"); font.bold: true
                    Layout.alignment: Qt.AlignTop
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.description
                }
                Label {
                    text: itemDefinitionViewDialog.item ? (itemDefinitionViewDialog.item.description || "") : ""
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    visible: itemDefinitionViewDialog.item && itemDefinitionViewDialog.item.description
                }
            }
        }

        onClosed: item = null
    }

    Dialog {
        id: itemDefinitionEditDialog
        property int editingId: -1

        readonly property bool isValid: {
            if (!itemDefNameField.text.trim()) return false
            if (itemDefTypeField.currentValue === Enums.ItemType.Weapon) {
                const dice = weaponDamageDiceField.text.trim()
                if (!/^[1-9]\d*(d[1-9]\d*)?$/.test(dice)) return false
            }
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
        width: 500
        height: Math.min(window.height - 60, 620)
        standardButtons: Dialog.Ok | Dialog.Cancel

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            GridLayout {
                width: itemDefinitionEditDialog.availableWidth - 20
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
                    visible: itemDefinitionEditDialog.containerEligible
                }
                CheckBox {
                    id: itemDefIsContainerField
                    visible: itemDefinitionEditDialog.containerEligible
                }

                Label {
                    text: qsTr("Capacity (lb)")
                    visible: itemDefinitionEditDialog.containerEligible && itemDefIsContainerField.checked
                }
                TextField {
                    id: itemDefCapacityField
                    Layout.fillWidth: true
                    visible: itemDefinitionEditDialog.containerEligible && itemDefIsContainerField.checked
                    validator: DoubleValidator { bottom: 0; decimals: 2; notation: DoubleValidator.StandardNotation }
                    placeholderText: qsTr("optional weight limit")
                }

                Label {
                    text: qsTr("Fixed weight (lb)")
                    visible: itemDefinitionEditDialog.containerEligible && itemDefIsContainerField.checked
                }
                TextField {
                    id: itemDefFixedWeightField
                    Layout.fillWidth: true
                    visible: itemDefinitionEditDialog.containerEligible && itemDefIsContainerField.checked
                    validator: DoubleValidator { bottom: 0; decimals: 2; notation: DoubleValidator.StandardNotation }
                    placeholderText: qsTr("e.g. Bag of Holding")
                }

                Label {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    text: qsTr("Weapon details")
                    font.bold: true
                    Layout.topMargin: 8
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                }

                Label {
                    text: qsTr("Category")
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                }
                ComboBox {
                    id: weaponCategoryField
                    Layout.fillWidth: true
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                    textRole: "name"
                    valueRole: "id"
                    model: [
                        { id: Enums.WeaponCategory.Simple, name: qsTr("Simple") },
                        { id: Enums.WeaponCategory.Martial, name: qsTr("Martial") }
                    ]
                }

                Label {
                    text: qsTr("Range")
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                }
                ComboBox {
                    id: weaponRangeField
                    Layout.fillWidth: true
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                    textRole: "name"
                    valueRole: "id"
                    model: [
                        { id: Enums.WeaponRangeType.Melee, name: qsTr("Melee") },
                        { id: Enums.WeaponRangeType.Ranged, name: qsTr("Ranged") }
                    ]
                }

                Label {
                    text: qsTr("Damage dice")
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                }
                TextField {
                    id: weaponDamageDiceField
                    Layout.fillWidth: true
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                    placeholderText: qsTr("e.g. 1d8 or 1")
                    validator: RegularExpressionValidator { regularExpression: /^[1-9]\d*(d[1-9]\d*)?$/ }
                }

                Label {
                    text: qsTr("Damage type")
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                }
                ComboBox {
                    id: weaponDamageTypeField
                    Layout.fillWidth: true
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                    textRole: "name"
                    valueRole: "id"
                    model: [
                        { id: Enums.DamageType.Bludgeoning, name: qsTr("Bludgeoning") },
                        { id: Enums.DamageType.Piercing, name: qsTr("Piercing") },
                        { id: Enums.DamageType.Slashing, name: qsTr("Slashing") },
                        { id: Enums.DamageType.Acid, name: qsTr("Acid") },
                        { id: Enums.DamageType.Cold, name: qsTr("Cold") },
                        { id: Enums.DamageType.Fire, name: qsTr("Fire") },
                        { id: Enums.DamageType.Force, name: qsTr("Force") },
                        { id: Enums.DamageType.Lightning, name: qsTr("Lightning") },
                        { id: Enums.DamageType.Necrotic, name: qsTr("Necrotic") },
                        { id: Enums.DamageType.Poison, name: qsTr("Poison") },
                        { id: Enums.DamageType.Psychic, name: qsTr("Psychic") },
                        { id: Enums.DamageType.Radiant, name: qsTr("Radiant") },
                        { id: Enums.DamageType.Thunder, name: qsTr("Thunder") }
                    ]
                }

                Label {
                    text: qsTr("Mastery")
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                }
                ComboBox {
                    id: weaponMasteryField
                    Layout.fillWidth: true
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                    model: ["", "Cleave", "Graze", "Nick", "Push", "Sap", "Slow", "Topple", "Vex"]
                    displayText: currentIndex === 0 ? qsTr("(none)") : currentText
                    delegate: ItemDelegate {
                        width: weaponMasteryField.width
                        text: modelData === "" ? qsTr("(none)") : modelData
                    }
                }

                Label {
                    text: qsTr("Ammunition")
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                             && weaponRangeField.currentValue === Enums.WeaponRangeType.Ranged
                }
                TextField {
                    id: weaponAmmoField
                    Layout.fillWidth: true
                    visible: itemDefTypeField.currentValue === Enums.ItemType.Weapon
                             && weaponRangeField.currentValue === Enums.WeaponRangeType.Ranged
                    placeholderText: qsTr("e.g. Arrow (optional)")
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
            weaponCategoryField.currentIndex = 0
            weaponRangeField.currentIndex = 0
            weaponDamageDiceField.text = ""
            weaponDamageTypeField.currentIndex = 0
            weaponMasteryField.currentIndex = 0
            weaponAmmoField.text = ""
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
                const wd = DB.getWeaponDetails(item.id)
                weaponCategoryField.currentIndex = wd.category !== undefined
                    ? weaponCategoryField.model.findIndex(c => c.id === wd.category) : 0
                weaponRangeField.currentIndex = wd.range_type !== undefined
                    ? weaponRangeField.model.findIndex(r => r.id === wd.range_type) : 0
                weaponDamageDiceField.text = wd.damage_dice || ""
                weaponDamageTypeField.currentIndex = wd.damage_type !== undefined
                    ? weaponDamageTypeField.model.findIndex(d => d.id === wd.damage_type) : 0
                const masteryList = ["", "Cleave", "Graze", "Nick", "Push", "Sap", "Slow", "Topple", "Vex"]
                const masteryIdx = masteryList.indexOf(wd.mastery || "")
                weaponMasteryField.currentIndex = masteryIdx >= 0 ? masteryIdx : 0
                weaponAmmoField.text = wd.ammunition_type || ""
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

            const isRanged = weaponRangeField.currentValue === Enums.WeaponRangeType.Ranged
            const weaponData = {
                "category": weaponCategoryField.currentValue,
                "range_type": weaponRangeField.currentValue,
                "damage_dice": weaponDamageDiceField.text.trim(),
                "damage_type": weaponDamageTypeField.currentValue,
                "properties": "[]",
                "mastery": weaponMasteryField.currentText || null,
                "ammunition_type": isRanged ? (weaponAmmoField.text.trim() || null) : null
            }

            const savedId = DB.saveItemDefinition(editingId, data, weaponData)
            if (savedId < 0)
                notifyError(DB.lastError() || qsTr("Couldn't save item."))
            else
                refreshCurrentDetail()
            resetForm()
        }
        onRejected: resetForm()
    }

    Dialog {
        id: catalogDeleteConfirm
        property var item: null

        title: qsTr("Delete Item?")
        modal: true
        anchors.centerIn: parent
        width: 380
        standardButtons: Dialog.Yes | Dialog.No

        Label {
            anchors.fill: parent
            text: catalogDeleteConfirm.item
                ? qsTr("Delete \"%1\"? This cannot be undone.").arg(catalogDeleteConfirm.item.name)
                : ""
            wrapMode: Text.Wrap
        }

        onAccepted: {
            if (item) {
                const ok = DB.deleteItemDefinition(item.id)
                if (!ok)
                    notifyError(DB.lastError() || qsTr("Couldn't delete item."))
                else
                    refreshCurrentDetail()
            }
            item = null
        }
        onRejected: item = null
    }

    FileDialog {
        id: exportFileDialog
        property int targetCharacterId: -1

        title: qsTr("Export to JSON")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("JSON files (*.json)")]
        defaultSuffix: "json"

        onAccepted: {
            const ok = targetCharacterId > 0
                ? DB.exportCharacterToFile(targetCharacterId, selectedFile)
                : DB.exportAllToFile(selectedFile)
            if (ok)
                notifyInfo(qsTr("Exported to %1").arg(selectedFile))
            else
                notifyError(DB.lastError() || qsTr("Export failed."))
            targetCharacterId = -1
        }
        onRejected: targetCharacterId = -1
    }

    FileDialog {
        id: importFileDialog
        title: qsTr("Import from JSON")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("JSON files (*.json)")]

        onAccepted: {
            const count = DB.importFromFile(selectedFile)
            if (count < 0) {
                notifyError(DB.lastError() || qsTr("Import failed."))
            } else {
                refresh()
                notifyInfo(qsTr("Imported %1 character(s).").arg(count))
            }
        }
    }

    Popup {
        id: errorBanner
        property string message: ""
        property bool isError: true
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose

        x: 16
        y: parent.height - height - 16
        width: parent.width - 32
        height: 56
        z: 100

        background: Rectangle {
            color: errorBanner.isError
                ? Material.color(Material.Red, Material.Shade700)
                : Material.color(Material.Green, Material.Shade700)
            radius: 4
        }

        contentItem: Label {
            text: errorBanner.message
            color: "white"
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignVCenter
        }
    }

    Timer {
        id: errorTimer
        interval: 4000
        repeat: false
        onTriggered: errorBanner.close()
    }

    InputPanel {
        id: inputPanel
        z: 99
        y: window.height
        width: window.width

        states: State {
            name: "visible"
            when: inputPanel.active
            PropertyChanges {
                inputPanel.y: window.height - inputPanel.height
            }
        }
        transitions: Transition {
            from: ""
            to: "visible"
            reversible: true
            NumberAnimation {
                properties: "y"
                easing.type: Easing.InOutQuad
            }
        }
    }
}
