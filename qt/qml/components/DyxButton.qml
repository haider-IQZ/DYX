import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Button {
    id: root

    property color fillColor: tokens.colors.primary
    property color labelColor: tokens.colors.primaryForeground
    property color borderColor: "transparent"
    property bool ghost: false

    implicitHeight: 36
    implicitWidth: Math.max(90, contentItem.implicitWidth + 24)
    hoverEnabled: true

    Tokens { id: tokens }

    background: Rectangle {
        radius: tokens.radiusLg
        color: root.enabled
               ? (root.ghost
                  ? (root.hovered ? Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.75) : "transparent")
                  : (root.down ? Qt.darker(root.fillColor, 1.08) : root.hovered ? Qt.lighter(root.fillColor, 1.05) : root.fillColor))
               : Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, 0.45)
        border.width: 1
        border.color: root.ghost ? tokens.colors.border : root.borderColor
    }

    contentItem: Text {
        text: root.text
        color: root.enabled ? root.labelColor : Qt.rgba(root.labelColor.r, root.labelColor.g, root.labelColor.b, 0.6)
        font.pixelSize: tokens.type.button
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }
}
