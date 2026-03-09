import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    required property var appWindow

    color: tokens.colors.card
    height: tokens.titleBarHeight
    border.width: 0

    Tokens { id: tokens }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        onPressed: function(mouse) {
            if (root.appWindow && root.appWindow.startSystemMove) {
                root.appWindow.startSystemMove()
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: tokens.colors.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 8

        RowLayout {
            spacing: 8

            Repeater {
                model: [
                    { fill: "#ff5f57", symbol: "close", symbolColor: "#4a0002" },
                    { fill: "#febc2e", symbol: "minimize", symbolColor: "#995700" },
                    { fill: "#28c840", symbol: "maximize", symbolColor: "#006500" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: 12
                    height: 12
                    radius: 6
                    color: modelData.fill

                    IconGlyph {
                        anchors.centerIn: parent
                        visible: mouseArea.containsMouse
                        iconName: modelData.symbol
                        iconColor: modelData.symbolColor
                        font.pixelSize: 8
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            if (index === 0) {
                                root.appWindow.close()
                            } else if (index === 1) {
                                root.appWindow.showMinimized()
                            } else if (index === 2) {
                                if (root.appWindow.visibility === Window.Maximized) {
                                    root.appWindow.showNormal()
                                } else {
                                    root.appWindow.showMaximized()
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: 8

            Text {
                text: "DYX"
                color: tokens.colors.foreground
                font.pixelSize: tokens.type.titleBarTitle
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Text {
                text: "Download Manager"
                color: tokens.colors.mutedForeground
                font.pixelSize: tokens.type.titleBarSubtitle
                renderType: Text.NativeRendering
            }
        }

        Item { Layout.fillWidth: true }
        Item { Layout.preferredWidth: 56 }
    }
}
