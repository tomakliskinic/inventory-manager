import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import inventoryManager

Dialog {
    id: root
    property var item: null
    property int characterId: -1
    property var destinationOptions: []

    signal saved()
    signal failed(string message)

    title: qsTr("Move Item")
    modal: true
    Overlay.modal: Rectangle { color: "#80000000" }
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 420) - 32, 420)
    standardButtons: Dialog.Ok | Dialog.Cancel

    GridLayout {
        anchors.fill: parent
        columns: 2
        columnSpacing: 12
        rowSpacing: 8

        Label { text: qsTr("Destination") }
        ComboBox {
            id: moveDestCombo
            Layout.fillWidth: true
            model: root.destinationOptions
            textRole: "name"
            valueRole: "id"
        }
    }

    function openFor(itm, charId) {
        item = itm
        characterId = charId

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
        const opts = [{ id: -1, name: qsTr("Top level") }]
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

        const currentParent = itm.parent_inventory_item_id || -1
        const idx = opts.findIndex(o => o.id === currentParent)
        moveDestCombo.currentIndex = idx >= 0 ? idx : 0

        open()
    }

    onAccepted: {
        if (item && moveDestCombo.currentValue !== undefined) {
            const ok = DB.updateInventoryItem(item.id, {
                "parent_inventory_item_id": moveDestCombo.currentValue
            })
            if (!ok)
                failed(DB.lastError() || qsTr("Couldn't move item."))
            saved()
        }
        item = null
        characterId = -1
    }
    onRejected: {
        item = null
        characterId = -1
    }
}
