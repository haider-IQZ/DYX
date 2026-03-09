import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

DyxDialog {
    id: root

    property string defaultSavePath: ""
    signal addDownload(string url, string savePath)

    dialogWidth: tokens.px(520)

    Tokens { id: tokens }

    onOpened: {
        urlInput.text = ""
        savePathInput.text = defaultSavePath
    }

    DirectoryPickerDialog {
        id: directoryPicker
        hostWindow: root.hostWindow
        onPathSelected: function(path) {
            savePathInput.text = path
        }
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
                font.pixelSize: tokens.px(20)
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
                        fillColor: "transparent"
                        strokeColor: "transparent"
                        onClicked: directoryPicker.openAt(savePathInput.text)
                    }
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
                        root.addDownload(urlInput.text.trim(), savePathInput.text)
                        root.close()
                    }
                }
            }
        }
    }
}
