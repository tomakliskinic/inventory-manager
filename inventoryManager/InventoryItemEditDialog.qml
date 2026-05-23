import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root
    property int itemId: -1

    signal saved()
    signal failed(string message)

    title: qsTr("Edit Item")
    modal: true
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 480) - 32, 480)
    height: Math.min((parent ? parent.height : 460) - 60, 460)
    standardButtons: Dialog.Ok | Dialog.Cancel

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        GridLayout {
            width: root.availableWidth - 20
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
                failed(DB.lastError() || qsTr("Couldn't update item."))
            saved()
        }
        itemId = -1
    }
    onRejected: itemId = -1
}
