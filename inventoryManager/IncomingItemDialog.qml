import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root

    property string senderName: ""
    property string itemName: ""
    property string payloadJson: ""
    property var characters: []
    property int selectedCharacterId: -1

    readonly property bool isNewHomebrew: itemName !== ""
        && !DB.itemDefinitionExistsByName(itemName)
    readonly property bool canAccept: selectedCharacterId > 0

    signal imported(int characterId, int newInventoryItemId)
    signal importFailed(string reason)

    function openFor(sender, item, payload) {
        senderName = sender
        itemName = item
        payloadJson = payload
        characters = DB.getAllCharacters()
        selectedCharacterId = characters.length > 0 ? characters[0].id : -1
        open()
    }

    title: qsTr("Incoming Item")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: parent
    width: Math.min(parent.width - 32, 420)
    standardButtons: Dialog.Yes | Dialog.No

    Component.onCompleted: {
        standardButton(Dialog.Yes).text = qsTr("Accept")
        standardButton(Dialog.No).text = qsTr("Decline")
    }
    onCanAcceptChanged: {
        const btn = standardButton(Dialog.Yes)
        if (btn) btn.enabled = canAccept
    }
    onOpened: {
        const btn = standardButton(Dialog.Yes)
        if (btn) btn.enabled = canAccept
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Label {
            Layout.fillWidth: true
            text: qsTr("%1 wants to give you \"%2\".")
                    .arg(root.senderName || qsTr("A peer"))
                    .arg(root.itemName)
            wrapMode: Text.Wrap
        }

        Label {
            Layout.fillWidth: true
            visible: root.isNewHomebrew
            text: qsTr("This item isn't in your catalog yet. Accepting will add it to your homebrew catalog.")
            opacity: 0.7
            wrapMode: Text.Wrap
            font.italic: true
        }

        Label {
            Layout.fillWidth: true
            visible: root.characters.length === 0
            text: qsTr("You have no characters yet. Create one before accepting items.")
            wrapMode: Text.Wrap
            color: Material.color(Material.Red)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.characters.length > 0
            spacing: 8

            Label { text: qsTr("Give to:") }
            ComboBox {
                Layout.fillWidth: true
                model: root.characters
                textRole: "name"
                valueRole: "id"
                currentIndex: 0
                Component.onCompleted: popup.bottomMargin = 80
                onActivated: root.selectedCharacterId = currentValue
            }
        }
    }

    onAccepted: {
        if (selectedCharacterId <= 0) {
            Net.respondToItemTransfer(false)
            importFailed(qsTr("No character selected"))
            payloadJson = ""
            return
        }
        const newId = DB.importInventoryItemFromShare(payloadJson, selectedCharacterId)
        if (newId < 0) {
            Net.respondToItemTransfer(false)
            importFailed(DB.lastError() || qsTr("Couldn't import item."))
        } else {
            Net.respondToItemTransfer(true)
            imported(selectedCharacterId, newId)
        }
        payloadJson = ""
    }

    onRejected: {
        Net.respondToItemTransfer(false)
        payloadJson = ""
    }

    onClosed: {
        if (payloadJson.length > 0) {
            Net.respondToItemTransfer(false)
            payloadJson = ""
        }
    }
}
