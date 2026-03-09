import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

TextField {
    id: root

    property string leadingIcon: ""

    leftPadding: leadingIcon.length > 0 ? 38 : 12
    rightPadding: 12
    topPadding: 0
    bottomPadding: 0
    implicitHeight: 36
    color: tokens.colors.foreground
    placeholderTextColor: tokens.colors.mutedForeground
    font.pixelSize: tokens.type.body
    selectByMouse: true
    verticalAlignment: Text.AlignVCenter

    Tokens { id: tokens }

    background: Rectangle {
        radius: tokens.radiusLg
        color: tokens.colors.muted
        border.width: 1
        border.color: root.activeFocus ? tokens.colors.ring : tokens.colors.border

        IconGlyph {
            visible: root.leadingIcon.length > 0
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            iconName: root.leadingIcon
            iconColor: tokens.colors.mutedForeground
            font.pixelSize: 15
        }
    }
}
