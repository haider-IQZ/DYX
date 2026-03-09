import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    required property var appWindow
    readonly property int chromeButtonSize: tokens.windowChromeButtonSize
    readonly property int chromeIconSize: tokens.windowChromeIconSize

    color: tokens.colors.card
    height: tokens.windowChromeHeight
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: tokens.windowChromeSidePadding
        anchors.rightMargin: tokens.windowChromeSidePadding
        spacing: tokens.windowChromeGap

        RowLayout {
            spacing: tokens.windowChromeGap

            Repeater {
                model: [
                    { fill: "#ff5f57", symbol: "close", symbolColor: "#4a0002" },
                    { fill: "#febc2e", symbol: "minimize", symbolColor: "#995700" },
                    { fill: "#28c840", symbol: "maximize", symbolColor: "#006500" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: root.chromeButtonSize
                    height: root.chromeButtonSize
                    radius: width / 2
                    color: modelData.fill

                    IconGlyph {
                        anchors.centerIn: parent
                        visible: mouseArea.containsMouse
                        iconName: modelData.symbol
                        iconColor: modelData.symbolColor
                        font.pixelSize: root.chromeIconSize
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
            spacing: tokens.windowChromeGap

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
