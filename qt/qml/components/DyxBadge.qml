import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    property string text: ""
    property color backgroundColor: Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.12)
    property color textColor: tokens.colors.primary

    radius: tokens.radiusMd
    color: backgroundColor
    implicitHeight: 22
    implicitWidth: badgeLabel.implicitWidth + tokens.spacing.md

    Tokens { id: tokens }

    Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.pixelSize: tokens.type.micro
        font.weight: Font.Medium
        renderType: Text.NativeRendering
    }
}
