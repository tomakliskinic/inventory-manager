import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root

    property string senderName: ""
    property int itemCount: 0
    property string packJson: ""

    signal importCompleted(int imported, var skipped)
    signal importFailed(string reason)
    signal declined()

    function openFor(sender, count, json) {
        senderName = sender
        itemCount = count
        packJson = json
        open()
    }

    title: qsTr("Incoming Homebrew Pack")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    anchors.centerIn: parent
    width: Math.min(parent.width - 32, 420)
    standardButtons: Dialog.Yes | Dialog.No

    Component.onCompleted: {
        standardButton(Dialog.Yes).text = qsTr("Accept")
        standardButton(Dialog.No).text = qsTr("Decline")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Label {
            Layout.fillWidth: true
            text: qsTr("%1 wants to share %2 homebrew item(s) with you.")
                    .arg(root.senderName || qsTr("A peer"))
                    .arg(root.itemCount)
            wrapMode: Text.Wrap
        }
        Label {
            Layout.fillWidth: true
            text: qsTr("Items with names already in your catalog will be skipped.")
            opacity: 0.6
            wrapMode: Text.Wrap
        }
    }

    onAccepted: {
        const imported = DB.importHomebrewPackFromJson(packJson)
        if (imported < 0) {
            importFailed(DB.lastError() || qsTr("Import failed."))
        } else {
            importCompleted(imported, DB.lastSkippedItems())
        }
        packJson = ""
    }

    onRejected: {
        declined()
        packJson = ""
    }
}
