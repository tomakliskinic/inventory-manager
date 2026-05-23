import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtQuick.Layouts
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
    property bool confirmedQuit: false
    readonly property bool isNarrow: width < 480

    Component.onCompleted: refresh()

    function refresh() {
        characters = DB.getAllCharacters()
    }

    onClosing: function(close) {
        if (Qt.platform.os !== "android") return
        if (confirmedQuit) return
        if (stack.depth > 1) {
            stack.pop()
            close.accepted = false
            return
        }
        if (!quitConfirm.opened) {
            quitConfirm.open()
            close.accepted = false
        }
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
        initialItem: listPageComponent
    }

    Shortcut {
        sequence: "Escape"
        enabled: !characterDialog.opened
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
                 && !quitConfirm.opened
        onActivated: {
            if (stack.depth > 1) stack.pop()
            else quitConfirm.open()
        }
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

                RowLayout {
                    anchors.fill: parent
                    Item { Layout.fillWidth: true }
                    ToolButton {
                        visible: !window.isNarrow
                        text: qsTr("Items")
                        onClicked: stack.push(itemCatalogPageComponent)
                    }
                    ToolButton {
                        visible: !window.isNarrow
                        text: qsTr("Import")
                        onClicked: importFileDialog.open()
                    }
                    ToolButton {
                        visible: !window.isNarrow
                        text: qsTr("Export all")
                        enabled: characters.length > 0
                        onClicked: {
                            exportFileDialog.targetCharacterId = -1
                            exportFileDialog.open()
                        }
                    }
                    OverflowMenuButton {
                        visible: window.isNarrow
                        font.pixelSize: 20
                        MenuItem {
                            text: qsTr("Items")
                            onTriggered: stack.push(itemCatalogPageComponent)
                        }
                        MenuItem {
                            text: qsTr("Import")
                            onTriggered: importFileDialog.open()
                        }
                        MenuItem {
                            text: qsTr("Export all")
                            enabled: characters.length > 0
                            onTriggered: {
                                exportFileDialog.targetCharacterId = -1
                                exportFileDialog.open()
                            }
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
                        OverflowMenuButton {
                            font.pixelSize: 18
                            MenuItem {
                                text: qsTr("Edit")
                                onTriggered: characterDialog.openEdit(modelData)
                            }
                            MenuItem {
                                text: qsTr("Delete")
                                onTriggered: {
                                    deleteConfirm.character = modelData
                                    deleteConfirm.open()
                                }
                            }
                        }
                    }

                    onClicked: stack.push(detailPageComponent, { "character": modelData })
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
            property int sortField: 0
            property bool sortAscending: true
            property bool selectionMode: false
            property var selectedIds: ({})
            readonly property int selectedCount: Object.keys(selectedIds).length

            function toggleSelection(id) {
                const next = Object.assign({}, selectedIds)
                if (next[id]) delete next[id]
                else next[id] = true
                selectedIds = next
            }

            function isSelected(id) {
                return selectedIds[id] === true
            }

            function enterSelectionMode() {
                selectionMode = true
                selectedIds = ({})
            }

            function exitSelectionMode() {
                selectionMode = false
                selectedIds = ({})
            }

            function selectedIdsArray() {
                return Object.keys(selectedIds).map(s => parseInt(s, 10))
            }

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
                if (sortField > 0) {
                    let cmp
                    if (sortField === 1)
                        cmp = (a, b) => (a.name || "").localeCompare(b.name || "")
                    else if (sortField === 2)
                        cmp = (a, b) => (a.weight_lb || 0) - (b.weight_lb || 0)
                    else
                        cmp = (a, b) => Utils.costInCopper(a.cost) - Utils.costInCopper(b.cost)
                    if (!sortAscending) {
                        const inner = cmp
                        cmp = (a, b) => -inner(a, b)
                    }
                    result = result.slice().sort(cmp)
                }
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
                    visible: !catalogPage.selectionMode

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
                        visible: !window.isNarrow
                        text: qsTr("Import")
                        onClicked: homebrewImportDialog.open()
                    }
                    ToolButton {
                        visible: !window.isNarrow
                        text: qsTr("Export")
                        onClicked: homebrewExportDialog.open()
                    }
                    ToolButton {
                        visible: !window.isNarrow
                        text: qsTr("Select")
                        onClicked: catalogPage.enterSelectionMode()
                    }
                    ToolButton {
                        text: qsTr("+ Add")
                        onClicked: itemDefinitionEditDialog.openCreate()
                    }
                    OverflowMenuButton {
                        visible: window.isNarrow
                        font.pixelSize: 20
                        MenuItem {
                            text: qsTr("Import")
                            onTriggered: homebrewImportDialog.open()
                        }
                        MenuItem {
                            text: qsTr("Export")
                            onTriggered: homebrewExportDialog.open()
                        }
                        MenuItem {
                            text: qsTr("Select")
                            onTriggered: catalogPage.enterSelectionMode()
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    visible: catalogPage.selectionMode

                    ToolButton {
                        text: qsTr("Cancel")
                        onClicked: catalogPage.exitSelectionMode()
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("%1 selected").arg(catalogPage.selectedCount)
                        font.pixelSize: 18
                    }
                    ToolButton {
                        text: qsTr("Export selected")
                        enabled: catalogPage.selectedCount > 0
                        onClicked: homebrewExportDialog.open()
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
                }

                RowLayout {
                    Layout.fillWidth: true

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
                        onActivated: catalogPage.filterType = currentValue
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
                        onActivated: catalogPage.filterSource = currentValue
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    ComboBox {
                        Layout.fillWidth: true
                        textRole: "name"
                        valueRole: "id"
                        model: [
                            { id: 0, name: qsTr("Default order") },
                            { id: 1, name: qsTr("Name") },
                            { id: 2, name: qsTr("Weight") },
                            { id: 3, name: qsTr("Cost") }
                        ]
                        onActivated: {
                            catalogPage.sortField = currentValue
                            catalogPage.sortAscending = currentValue === 1
                        }
                    }
                    ToolButton {
                        text: catalogPage.sortAscending ? "↑" : "↓"
                        enabled: catalogPage.sortField > 0
                        onClicked: catalogPage.sortAscending = !catalogPage.sortAscending
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
                        id: catalogRow
                        width: ListView.view.width

                        readonly property bool isHomebrew: modelData.source === Enums.ItemSource.Homebrew
                        readonly property bool selectable: catalogPage.selectionMode && isHomebrew

                        contentItem: RowLayout {
                            Item {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                visible: catalogPage.selectionMode

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    radius: 2
                                    visible: catalogRow.selectable
                                    border.color: Material.foreground
                                    border.width: 2
                                    color: catalogPage.isSelected(modelData.id) ? Material.accent : "transparent"

                                    Label {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "white"
                                        font.bold: true
                                        visible: catalogPage.isSelected(modelData.id)
                                    }
                                }
                            }
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
                            OverflowMenuButton {
                                visible: modelData.source === Enums.ItemSource.Homebrew
                                          && !catalogPage.selectionMode
                                MenuItem {
                                    text: qsTr("Edit")
                                    onTriggered: itemDefinitionEditDialog.openEdit(modelData)
                                }
                                MenuItem {
                                    text: qsTr("Delete")
                                    onTriggered: {
                                        catalogDeleteConfirm.item = modelData
                                        catalogDeleteConfirm.open()
                                    }
                                }
                            }
                        }

                        onClicked: {
                            if (catalogRow.selectable)
                                catalogPage.toggleSelection(modelData.id)
                            else
                                itemDefinitionViewDialog.openFor(modelData)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: detailPageComponent

        CharacterDetailPage {
            onBack: stack.pop()
            onEditCharacterRequested: c => characterDialog.openEdit(c)
            onExportRequested: id => {
                exportFileDialog.targetCharacterId = id
                exportFileDialog.open()
            }
            onDeleteCharacterRequested: c => {
                deleteConfirm.character = c
                deleteConfirm.open()
            }
            onEditCoinsRequested: id => coinsDialog.openFor(id)
            onAddItemRequested: id => addItemDialog.openFor(id)
            onEditItemRequested: it => itemEditDialog.openFor(it)
            onMoveItemRequested: (it, charId) => itemMoveDialog.openFor(it, charId)
            onRemoveContainerRequested: (it, charId) => itemRemoveContainerDialog.openFor(it, charId)
            onRemoveItemRequested: it => {
                itemRemoveSimpleConfirm.item = it
                itemRemoveSimpleConfirm.open()
            }
            onViewItemDefinitionRequested: id => {
                const itemDef = DB.getItemDefinition(id)
                if (itemDef && itemDef.id)
                    itemDefinitionViewDialog.openFor(itemDef)
            }
        }
    }

    CharacterEditDialog {
        id: characterDialog
        onSaved: {
            refresh()
            refreshCurrentDetail()
        }
    }

    Dialog {
        id: deleteConfirm
        property var character: null

        title: qsTr("Delete Character?")
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 360)
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
        id: quitConfirm
        title: qsTr("Exit?")
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 360)
        standardButtons: Dialog.Yes | Dialog.No

        Label {
            anchors.fill: parent
            text: qsTr("Exit Inventory Manager?")
            wrapMode: Text.Wrap
        }

        onAccepted: {
            window.confirmedQuit = true
            Qt.quit()
        }
    }

    CoinsDialog {
        id: coinsDialog
        onSaved: refreshCurrentDetail()
    }

    AddItemDialog {
        id: addItemDialog
        onSaved: refreshCurrentDetail()
        onFailed: msg => notifyError(msg)
    }

    InventoryItemEditDialog {
        id: itemEditDialog
        onSaved: refreshCurrentDetail()
        onFailed: msg => notifyError(msg)
    }

    Dialog {
        id: itemRemoveSimpleConfirm
        property var item: null

        title: qsTr("Remove Item?")
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 360)
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

    ItemRemoveContainerDialog {
        id: itemRemoveContainerDialog
        onSaved: refreshCurrentDetail()
        onFailed: msg => notifyError(msg)
    }

    ItemMoveDialog {
        id: itemMoveDialog
        onSaved: refreshCurrentDetail()
        onFailed: msg => notifyError(msg)
    }

    ItemDefinitionViewDialog {
        id: itemDefinitionViewDialog
    }

    ItemDefinitionEditDialog {
        id: itemDefinitionEditDialog
        onSaveFailed: msg => notifyError(msg)
        onSaved: refreshCurrentDetail()
    }

    Dialog {
        id: catalogDeleteConfirm
        property var item: null

        title: qsTr("Delete Item?")
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 380)
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

    FileDialog {
        id: homebrewExportDialog
        title: qsTr("Export Homebrew Pack")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("JSON files (*.json)")]
        defaultSuffix: "json"

        onAccepted: {
            const ids = (stack.currentItem && stack.currentItem.selectionMode)
                      ? stack.currentItem.selectedIdsArray()
                      : []
            if (DB.exportHomebrewPack(selectedFile, ids)) {
                const label = ids.length > 0
                    ? qsTr("Exported %1 item(s) to %2").arg(ids.length).arg(selectedFile)
                    : qsTr("Exported homebrew pack to %1").arg(selectedFile)
                notifyInfo(label)
                if (stack.currentItem && stack.currentItem.selectionMode)
                    stack.currentItem.exitSelectionMode()
            } else {
                notifyError(DB.lastError() || qsTr("Export failed."))
            }
        }
    }

    FileDialog {
        id: homebrewImportDialog
        title: qsTr("Import Homebrew Pack")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("JSON files (*.json)")]

        onAccepted: {
            const count = DB.importHomebrewPack(selectedFile)
            if (count < 0) {
                notifyError(DB.lastError() || qsTr("Import failed."))
                return
            }
            const skipped = DB.lastSkippedItems()
            if (stack.currentItem && stack.currentItem.refresh)
                stack.currentItem.refresh()
            if (skipped.length === 0)
                notifyInfo(qsTr("Imported %1 item(s).").arg(count))
            else
                notifyInfo(qsTr("Imported %1, skipped %2 (already exist): %3")
                    .arg(count).arg(skipped.length).arg(skipped.join(", ")))
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

}
