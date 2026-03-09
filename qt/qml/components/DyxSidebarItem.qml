import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Button {
    id: root

    property string iconName: "download"
    property int count: -1
    property bool active: false
    property bool compactMode: false

    implicitHeight: tokens.px(compactMode ? 40 : 36)
    hoverEnabled: true
    leftPadding: tokens.px(compactMode ? 8 : 12)
    rightPadding: tokens.px(compactMode ? 8 : 12)

    Tokens { id: tokens }

    ToolTip.visible: root.compactMode && root.hovered
    ToolTip.delay: 250
    ToolTip.text: root.text

    background: Rectangle {
        radius: tokens.radiusLg
        color: root.active
               ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.12)
               : (root.hovered ? tokens.colors.muted : "transparent")
        border.width: root.active ? 1 : 0
        border.color: root.active ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.3) : "transparent"
    }

    contentItem: Item {
        implicitWidth: root.compactMode ? tokens.px(40) : expandedContent.implicitWidth
        implicitHeight: root.compactMode ? tokens.px(40) : expandedContent.implicitHeight

        RowLayout {
            id: expandedContent
            anchors.fill: parent
            visible: !root.compactMode
            spacing: tokens.px(12)

            Item {
                Layout.preferredWidth: tokens.px(18)
                Layout.preferredHeight: tokens.px(18)

                IconGlyph {
                    anchors.centerIn: parent
                    iconName: root.iconName
                    iconColor: root.active ? tokens.colors.primary : tokens.colors.mutedForeground
                    font.pixelSize: tokens.px(15)
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
                radius: tokens.px(10)
                implicitWidth: badgeLabel.implicitWidth + tokens.px(12)
                implicitHeight: tokens.px(20)

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

        Item {
            anchors.fill: parent
            visible: root.compactMode

            IconGlyph {
                anchors.centerIn: parent
                iconName: root.iconName
                iconColor: root.active ? tokens.colors.primary : tokens.colors.mutedForeground
                font.pixelSize: tokens.px(16)
            }
        }
    }
}
