import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Button {
    id: root

    property string iconName: "download"
    property int count: -1
    property bool active: false

    implicitHeight: 36
    hoverEnabled: true
    leftPadding: 12
    rightPadding: 12

    Tokens { id: tokens }

    background: Rectangle {
        radius: tokens.radiusLg
        color: root.active
               ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.12)
               : (root.hovered ? tokens.colors.muted : "transparent")
        border.width: root.active ? 1 : 0
        border.color: root.active ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.3) : "transparent"
    }

    contentItem: RowLayout {
        spacing: 12

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18

            IconGlyph {
                anchors.centerIn: parent
                iconName: root.iconName
                iconColor: root.active ? tokens.colors.primary : tokens.colors.mutedForeground
                font.pixelSize: 15
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.text
            color: root.active ? tokens.colors.foreground : tokens.colors.mutedForeground
            font.pixelSize: tokens.type.bodySmall
            font.weight: root.active ? Font.Medium : Font.Normal
            renderType: Text.NativeRendering
            elide: Text.ElideRight
        }

        Rectangle {
            visible: root.count >= 0
            color: root.active ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.3) : tokens.colors.muted
            radius: 10
            implicitWidth: badgeLabel.implicitWidth + 12
            implicitHeight: 20

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: String(root.count)
                color: root.active ? tokens.colors.primary : tokens.colors.mutedForeground
                font.pixelSize: tokens.type.micro
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }
        }
    }
}
