import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root

    property bool pickMode: false
    property string pendingPackJson: ""
    property int pendingPackCount: 0
    signal pickedForShare(string uuid, string name, int count)

    function openForShare(json, count) {
        pendingPackJson = json || ""
        pendingPackCount = count
        pickMode = true
        open()
    }

    title: pickMode ? qsTr("Share With…") : qsTr("Discover Peers")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    anchors.centerIn: parent
    width: Math.min(parent.width - 32, 480)
    height: Math.min(parent.height - 64, 520)
    standardButtons: pickMode ? Dialog.Cancel : Dialog.Close

    onClosed: {
        pendingPackJson = ""
        pendingPackCount = 0
        pickMode = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label { text: qsTr("My device name:") }

            TextField {
                Layout.fillWidth: true
                text: Net.deviceName
                onEditingFinished: Net.deviceName = text
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Material.foreground
            opacity: 0.1
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: emptyState
                anchors.centerIn: parent
                spacing: 8
                visible: Net.peers.length === 0
                width: Math.min(parent.width - 16, 320)

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    running: emptyState.visible
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Looking for peers on this network…")
                    opacity: 0.6
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Other devices running this app on the same Wi-Fi appear here.")
                    opacity: 0.5
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ListView {
                anchors.fill: parent
                visible: Net.peers.length > 0
                model: Net.peers
                spacing: 4
                clip: true

                delegate: ItemDelegate {
                    width: ListView.view.width
                    opacity: root.pickMode ? 1.0 : 0.6

                    contentItem: ColumnLayout {
                        spacing: 2
                        Label {
                            text: modelData.name || qsTr("(unnamed)")
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: modelData.address
                            opacity: 0.6
                            font.pixelSize: 12
                        }
                    }

                    onClicked: {
                        if (!root.pickMode)
                            return
                        if (root.pendingPackJson.length > 0) {
                            Net.sendPackJson(modelData.uuid, root.pendingPackJson)
                            root.pickedForShare(modelData.uuid,
                                                modelData.name || "",
                                                root.pendingPackCount)
                        }
                        root.close()
                    }
                }
            }
        }
    }
}
