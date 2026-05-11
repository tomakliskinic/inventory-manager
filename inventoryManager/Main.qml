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
