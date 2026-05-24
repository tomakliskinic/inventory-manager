import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root
    property int characterId: -1

    signal saved()

    title: qsTr("Edit Coins")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 360) - 32, 360)
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
            saved()
        }
        characterId = -1
    }
    onRejected: characterId = -1
}
