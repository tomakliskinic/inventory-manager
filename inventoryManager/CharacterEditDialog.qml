import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root
    property int editingId: -1

    signal saved()

    title: editingId === -1 ? qsTr("New Character") : qsTr("Edit Character")
    modal: true
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 480) - 32, 480)
    height: Math.min((parent ? parent.height : 560) - 60, 560)
    standardButtons: Dialog.Ok | Dialog.Cancel

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        GridLayout {
            width: root.availableWidth - 20
            columns: 2
            columnSpacing: 12
            rowSpacing: 8

            Label { text: qsTr("Name") }
            TextField {
                id: nameField
                Layout.fillWidth: true
                onAccepted: root.accept()
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
        saved()
        resetForm()
    }
    onRejected: resetForm()
}
