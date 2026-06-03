import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root

    property var preview: null
    property bool isAdd: false
    property int sourceId: -1
    property int targetId: -1
    property string sourceName: ""
    property string targetName: ""

    signal confirmed(int targetId, int sourceId)
    signal canceled()

    function openFor(previewMap) {
        if (!previewMap || Object.keys(previewMap).length === 0)
            return
        preview = previewMap
        isAdd = !!previewMap.isAdd
        sourceId = previewMap.sourceId !== undefined ? previewMap.sourceId : -1
        targetId = previewMap.targetId
        sourceName = previewMap.sourceName || ""
        targetName = previewMap.targetName || ""
        open()
    }

    title: qsTr("Tear a Rift to the Astral Plane?")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 480) - 32, 480)
    height: Math.min((parent ? parent.height : 560) - 60, 560)

    function formatRow(row) {
        const indent = "  ".repeat(row.depth || 0)
        const qty = row.quantity > 1 ? qsTr(" ×%1").arg(row.quantity) : ""
        return indent + "• " + row.name + qty
    }

    contentItem: ColumnLayout {
        spacing: 10

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.isAdd
                ? qsTr("Placing %1 inside %2 opens a one-way gate to the Astral Plane.")
                    .arg(root.sourceName).arg(root.targetName)
                : qsTr("Moving %1 inside %2 opens a one-way gate to the Astral Plane.")
                    .arg(root.sourceName).arg(root.targetName)
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.8
            font.italic: true
            text: qsTr("Per SRD 5.2, both items and everything inside them are destroyed. Any creature within 10 feet would be sucked through and stranded.")
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("The following will be lost:")
            font.bold: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: root.availableWidth - 32
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    visible: !root.isAdd && root.preview && root.preview.sourceContents
                             && root.preview.sourceContents.length > 0
                    text: root.preview ? root.preview.sourceContents
                        .map(r => root.formatRow(r)).join("\n") : ""
                    wrapMode: Text.Wrap
                    font.family: "monospace"
                    font.pixelSize: 13
                }

                Label {
                    Layout.fillWidth: true
                    visible: root.preview && root.preview.targetContents
                             && root.preview.targetContents.length > 0
                    text: root.preview ? root.preview.targetContents
                        .map(r => root.formatRow(r)).join("\n") : ""
                    wrapMode: Text.Wrap
                    font.family: "monospace"
                    font.pixelSize: 13
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8

            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Cancel")
                flat: true
                onClicked: {
                    root.canceled()
                    root.close()
                }
            }
            Button {
                text: qsTr("Tear the rift")
                Material.background: Material.color(Material.Red, Material.Shade700)
                Material.foreground: "white"
                onClicked: {
                    root.confirmed(root.targetId, root.sourceId)
                    root.close()
                }
            }
        }
    }
}
