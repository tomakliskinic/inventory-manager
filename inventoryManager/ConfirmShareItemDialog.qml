import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Dialog {
    id: root

    property var pendingItem: null
    property int chosenQuantity: 1

    readonly property bool stackable: pendingItem && pendingItem.quantity > 1
    readonly property bool container: pendingItem && pendingItem.is_container

    signal confirmed(int inventoryItemId, int quantity, string label)

    function openFor(item) {
        pendingItem = item
        chosenQuantity = 1
        open()
    }

    title: qsTr("Share Item")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    anchors.centerIn: parent
    width: Math.min(parent.width - 32, 380)
    standardButtons: Dialog.Cancel | Dialog.Ok

    Component.onCompleted: {
        standardButton(Dialog.Ok).text = qsTr("Next")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            Layout.fillWidth: true
            text: root.pendingItem
                ? qsTr("Give \"%1\" to another player?")
                    .arg(root.pendingItem.custom_name || root.pendingItem.item_name)
                : ""
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.stackable
            spacing: 8

            Label {
                text: qsTr("How many?")
            }
            SpinBox {
                Layout.fillWidth: true
                from: 1
                to: root.pendingItem ? root.pendingItem.quantity : 1
                value: root.chosenQuantity
                editable: true
                onValueChanged: root.chosenQuantity = value
            }
            Label {
                text: qsTr("/ %1").arg(root.pendingItem ? root.pendingItem.quantity : 1)
                opacity: 0.6
            }
        }

        Label {
            Layout.fillWidth: true
            visible: root.container
            text: qsTr("This container's contents will also be sent.")
            wrapMode: Text.Wrap
            opacity: 0.7
            font.italic: true
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("You'll choose the recipient next.")
            wrapMode: Text.Wrap
            opacity: 0.6
        }
    }

    onAccepted: {
        if (pendingItem) {
            const label = pendingItem.custom_name || pendingItem.item_name
            confirmed(pendingItem.id, root.stackable ? chosenQuantity : 1, label)
        }
        pendingItem = null
    }
    onRejected: pendingItem = null
}
