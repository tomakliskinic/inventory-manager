import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

ItemDelegate {
    id: root

    property var aggregateWeightFn

    signal toggleExpansionRequested(int id)
    signal viewInfoRequested(int itemId)
    signal editRequested(var item)
    signal moveRequested(var item)
    signal removeRequested(var item)
    signal shareRequested(var item)

    Layout.fillWidth: true
    padding: 4
    hoverEnabled: true

    onClicked: {
        if (modelData.is_container)
            toggleExpansionRequested(modelData.id)
        else
            viewInfoRequested(modelData.item_id)
    }

    background: Rectangle {
        color: Material.foreground
        opacity: root.pressed ? 0.12 : root.hovered ? 0.06 : 0
    }

    contentItem: RowLayout {
        Item {
            Layout.preferredWidth: modelData.depth * 20
            visible: modelData.depth > 0
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                text: (modelData.is_container ? "📦 " : "")
                      + (modelData.custom_name || modelData.item_name)
                      + (modelData.is_equipped ? " ✓" : "")
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Label {
                visible: modelData.is_container
                         && Number.isFinite(modelData.container_weight_capacity)
                         && modelData.container_weight_capacity > 0
                text: visible
                    ? qsTr("(%1/%2 lb)")
                        .arg(DB.getContainerUsedWeight(modelData.id).toFixed(1))
                        .arg(modelData.container_weight_capacity)
                    : ""
                Layout.fillWidth: true
                opacity: 0.5
                font.pixelSize: 12
            }
        }
        Label {
            text: qsTr("×%1").arg(modelData.quantity)
            opacity: 0.7
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
        }
        Label {
            text: {
                const perUnit = (Number.isFinite(modelData.fixed_weight) && modelData.fixed_weight > 0)
                    ? modelData.fixed_weight
                    : (modelData.weight_lb || 0)
                const own = (perUnit * modelData.quantity).toFixed(1)
                if (!modelData.is_container) return qsTr("%1 lb").arg(own)
                const agg = root.aggregateWeightFn(modelData).toFixed(1)
                if (agg === own) return qsTr("%1 lb").arg(own)
                return qsTr("%1 (%2) lb").arg(own).arg(agg)
            }
            opacity: 0.7
            Layout.preferredWidth: 90
            horizontalAlignment: Text.AlignRight
        }
        OverflowMenuButton {
            MenuItem {
                text: qsTr("View info")
                onTriggered: root.viewInfoRequested(modelData.item_id)
            }
            MenuItem {
                text: qsTr("Edit")
                onTriggered: root.editRequested(modelData)
            }
            MenuItem {
                text: qsTr("Move")
                onTriggered: root.moveRequested(modelData)
            }
            MenuItem {
                text: qsTr("Share…")
                onTriggered: root.shareRequested(modelData)
            }
            MenuItem {
                text: qsTr("Remove")
                onTriggered: root.removeRequested(modelData)
            }
        }
    }
}
