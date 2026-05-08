import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
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
        onActivated: stack.pop()
    }

    Component {
        id: listPageComponent

        Page {
            header: ToolBar {
                Label {
                    anchors.centerIn: parent
                    text: qsTr("Characters")
                    font.pixelSize: 18
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

                            Label {
                                Layout.fillWidth: true
                                visible: detailPage.inventoryItems.length === 0
                                text: qsTr("No items")
                                opacity: 0.5
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Repeater {
                                model: detailPage.inventoryItems
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
                                    text: qsTr("Remove")
                                    onTriggered: {
                                        const it = inventoryRowMenu.item
                                        if (it.is_container && DB.getContainerContents(it.id).length > 0) {
                                            itemRemoveContainerDialog.item = it
                                            itemRemoveContainerDialog.open()
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

        title: qsTr("Add Item")
        modal: true
        anchors.centerIn: parent
        width: 400
        standardButtons: Dialog.Ok | Dialog.Cancel

        GridLayout {
            anchors.fill: parent
            columns: 2
            columnSpacing: 12
            rowSpacing: 8

            Label { text: qsTr("Item") }
            ComboBox {
                id: itemCombo
                Layout.fillWidth: true
                model: addItemDialog.itemDefs
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
            itemCombo.currentIndex = 0
            qtyField.value = 1
            parentCombo.currentIndex = 0
            open()
        }

        onAccepted: {
            if (characterId > 0 && itemCombo.currentValue) {
                DB.addInventoryItem(characterId, itemCombo.currentValue, qtyField.value, parentCombo.currentValue)
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
                DB.updateInventoryItem(itemId, {
                    "quantity": itemQtyField.value,
                    "custom_name": itemNameField.text.trim() || null,
                    "notes": itemNotesField.text.trim() || null,
                    "is_equipped": itemEquippedField.checked ? 1 : 0
                })
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
                DB.removeInventoryItem(item.id)
                refreshCurrentDetail()
            }
            item = null
        }
        onRejected: item = null
    }

    Dialog {
        id: itemRemoveContainerDialog
        property var item: null

        title: qsTr("Remove Container?")
        modal: true
        anchors.centerIn: parent
        width: 420

        function applyMode(mode) {
            if (item) {
                DB.removeInventoryItem(item.id, mode)
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
