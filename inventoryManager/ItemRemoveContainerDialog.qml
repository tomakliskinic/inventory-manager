import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root
    property var item: null
    property var destinationOptions: []

    signal saved()
    signal failed(string message)

    title: qsTr("Remove Container?")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 460) - 32, 460)

    function openFor(itm, charId) {
        item = itm

        const allItems = DB.getInventoryTree(charId)
        const excluded = new Set([itm.id])
        let changed = true
        while (changed) {
            changed = false
            for (const i of allItems) {
                if (excluded.has(i.parent_inventory_item_id) && !excluded.has(i.id)) {
                    excluded.add(i.id)
                    changed = true
                }
            }
        }

        const containers = allItems.filter(i => i.is_container && !excluded.has(i.id))
        const opts = []
        for (const c of containers) {
            const path = []
            let cur = c
            while (cur) {
                path.unshift(cur.custom_name || cur.item_name)
                const parentId = cur.parent_inventory_item_id
                cur = parentId ? allItems.find(i => i.id === parentId) : null
            }
            opts.push({ id: c.id, name: path.join(" › ") })
        }
        destinationOptions = opts
        moveContentsCombo.currentIndex = 0
        open()
    }

    function applyMode(mode, destId) {
        if (item) {
            const ok = DB.removeInventoryItem(item.id, mode, destId !== undefined ? destId : -1)
            if (!ok)
                failed(DB.lastError() || qsTr("Couldn't remove item."))
            saved()
        }
        item = null
        close()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            text: root.item
                ? qsTr("\"%1\" contains items. What should happen to them?")
                    .arg(root.item.custom_name || root.item.item_name)
                : ""
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Button {
            text: qsTr("Spill contents out")
            Layout.fillWidth: true
            onClicked: root.applyMode(Enums.RemovalMode.SpillToParent)
        }
        Button {
            text: qsTr("Delete with all contents")
            Layout.fillWidth: true
            onClicked: root.applyMode(Enums.RemovalMode.DeleteAll)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.destinationOptions.length > 0

            ComboBox {
                id: moveContentsCombo
                Layout.fillWidth: true
                model: root.destinationOptions
                textRole: "name"
                valueRole: "id"
            }
            Button {
                text: qsTr("Move to")
                enabled: moveContentsCombo.currentValue !== undefined
                         && moveContentsCombo.currentValue > 0
                onClicked: root.applyMode(
                    Enums.RemovalMode.MoveToContainer, moveContentsCombo.currentValue)
            }
        }

        Button {
            text: qsTr("Cancel")
            Layout.fillWidth: true
            flat: true
            onClicked: {
                root.item = null
                root.close()
            }
        }
    }
}
