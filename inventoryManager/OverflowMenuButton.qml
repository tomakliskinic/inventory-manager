import QtQuick
import QtQuick.Controls

ToolButton {
    id: root

    default property alias menuItems: menu.contentData

    text: "…"
    font.pixelSize: 16

    onClicked: {
        const overlay = Overlay.overlay
        const sceneY = root.mapToItem(overlay, 0, 0).y
        const menuH = menu.implicitHeight
        menu.y = (sceneY + root.height + menuH + 64 > overlay.height)
              ? -menuH
              : root.height
        menu.open()
    }

    Menu {
        id: menu
        x: root.width - width
    }
}
