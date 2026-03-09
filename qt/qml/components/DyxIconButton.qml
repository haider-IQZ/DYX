import QtQuick 2.15
import QtQuick.Controls 2.15
import "../theme"

Button {
    id: root

    property string iconName: "file"
    property color iconColor: tokens.colors.foreground
    property color fillColor: tokens.colors.muted
    property color strokeColor: "transparent"
    property bool destructive: false

    implicitWidth: tokens.iconButtonSize
    implicitHeight: tokens.iconButtonSize
    hoverEnabled: true

    Tokens { id: tokens }

    readonly property bool ghost: root.fillColor.a === 0

    background: Rectangle {
        radius: tokens.radiusLg
        color: root.destructive
               ? (root.hovered ? Qt.rgba(tokens.colors.red.r, tokens.colors.red.g, tokens.colors.red.b, 0.3)
                               : Qt.rgba(tokens.colors.red.r, tokens.colors.red.g, tokens.colors.red.b, 0.2))
               : (root.ghost
                  ? (root.hovered ? Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.4) : "transparent")
                  : (root.hovered ? Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.8)
                                  : root.fillColor))
        border.width: root.destructive || !root.ghost || root.strokeColor !== "transparent" ? 1 : 0
        border.color: root.strokeColor === "transparent" ? tokens.colors.border : root.strokeColor
    }

    contentItem: IconGlyph {
        iconName: root.iconName
        iconColor: root.destructive ? tokens.colors.red : root.iconColor
        font.pixelSize: tokens.px(15)
    }
}
