import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

DyxDialog {
    id: root

    property string defaultSavePath: ""
    signal addDownload(string url, int connections, string savePath)
    signal browseRequested(string currentPath)

    dialogWidth: 560

    Tokens { id: tokens }

    onOpened: {
        urlInput.text = ""
        savePathInput.text = defaultSavePath
        connectionsSlider.value = 8
    }

    ColumnLayout {
        width: root.dialogWidth
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            Layout.bottomMargin: 0

            Text {
                text: "Add New Download"
                color: tokens.colors.foreground
                font.pixelSize: 20
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            DyxIconButton {
                iconName: "close"
                fillColor: "transparent"
                onClicked: root.close()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            spacing: 24

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Download URL"
                    color: tokens.colors.foreground
                    font.pixelSize: tokens.type.bodySmall
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                DyxInput {
                    id: urlInput
                    Layout.fillWidth: true
                    leadingIcon: "link"
                    placeholderText: "https://example.com/file.zip"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Save Location"
                    color: tokens.colors.foreground
                    font.pixelSize: tokens.type.bodySmall
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    DyxInput {
                        id: savePathInput
                        Layout.fillWidth: true
                        leadingIcon: "folder"
                    }

                    DyxIconButton {
                        iconName: "folder"
                        onClicked: root.browseRequested(savePathInput.text)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Connections"
                        color: tokens.colors.foreground
                        font.pixelSize: tokens.type.bodySmall
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: Math.round(connectionsSlider.value) + " parallel connections"
                        color: tokens.colors.primary
                        font.pixelSize: tokens.type.bodySmall
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }
                }

                Slider {
                    id: connectionsSlider
                    Layout.fillWidth: true
                    from: 1
                    to: 32
                    stepSize: 1
                    value: 8

                    background: Rectangle {
                        x: connectionsSlider.leftPadding
                        y: connectionsSlider.topPadding + connectionsSlider.availableHeight / 2 - height / 2
                        width: connectionsSlider.availableWidth
                        height: 4
                        radius: 2
                        color: tokens.colors.muted

                        Rectangle {
                            width: connectionsSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: tokens.colors.primary
                        }
                    }

                    handle: Rectangle {
                        x: connectionsSlider.leftPadding + connectionsSlider.visualPosition * (connectionsSlider.availableWidth - width)
                        y: connectionsSlider.topPadding + connectionsSlider.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: tokens.colors.foreground
                        border.width: 1
                        border.color: tokens.colors.border
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "1 (Slower)"
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.micro
                        renderType: Text.NativeRendering
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "32 (Faster)"
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.micro
                        renderType: Text.NativeRendering
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: tokens.radiusLg
                color: Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.5)
                border.width: 1
                border.color: tokens.colors.border
                implicitHeight: infoText.implicitHeight + 24

                Text {
                    id: infoText
                    anchors.fill: parent
                    anchors.margins: 12
                    text: "DYX uses axel under the hood for multi-connection accelerated downloads. More connections can speed up downloads from servers that support it."
                    color: tokens.colors.mutedForeground
                    font.pixelSize: tokens.type.caption
                    wrapMode: Text.WordWrap
                    renderType: Text.NativeRendering
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 12

                DyxButton {
                    text: "Cancel"
                    ghost: true
                    fillColor: "transparent"
                    labelColor: tokens.colors.foreground
                    onClicked: root.close()
                }

                DyxButton {
                    text: "Start Download"
                    enabled: urlInput.text.trim().length > 0
                    onClicked: {
                        if (urlInput.text.trim().length === 0)
                            return
                        root.addDownload(urlInput.text.trim(), Math.round(connectionsSlider.value), savePathInput.text)
                        root.close()
                    }
                }
            }
        }
    }
}
