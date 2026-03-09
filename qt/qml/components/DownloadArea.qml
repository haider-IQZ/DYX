import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    property var downloadsModel
    signal addNew()
    signal togglePause(string id)
    signal removeItem(string id)
    signal openFolder(string id)
    signal searchChanged(string query)

    color: tokens.colors.background

    Tokens { id: tokens }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: tokens.contentHeaderHeight
            color: "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: tokens.colors.border
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 16

                RowLayout {
                    spacing: 16

                    Text {
                        text: "Downloads"
                        color: tokens.colors.foreground
                        font.pixelSize: tokens.type.sectionHeading
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: {
                            const count = downloadsModel ? downloadsModel.count : 0
                            return count + (count === 1 ? " item" : " items")
                        }
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.bodySmall
                        renderType: Text.NativeRendering
                    }
                }

                Item { Layout.fillWidth: true }

                DyxInput {
                    id: searchInput
                    Layout.preferredWidth: 256
                    leadingIcon: "search"
                    placeholderText: "Search downloads..."
                    onTextChanged: root.searchChanged(text)
                }

                DyxButton {
                    text: "Add URL"
                    onClicked: root.addNew()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            Loader {
                anchors.fill: parent
                active: !downloadsModel || downloadsModel.count === 0
                sourceComponent: Item {
                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 64
                            height: 64
                            radius: 32
                            color: tokens.colors.muted

                            IconGlyph {
                                anchors.centerIn: parent
                                iconName: "plus"
                                iconColor: tokens.colors.mutedForeground
                                font.pixelSize: 26
                            }
                        }

                        Text {
                            text: "No downloads yet"
                            color: tokens.colors.foreground
                            font.pixelSize: 18
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            width: 260
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: "Click \"Add URL\" to start downloading files"
                            color: tokens.colors.mutedForeground
                            font.pixelSize: tokens.type.bodySmall
                            horizontalAlignment: Text.AlignHCenter
                            width: 280
                            wrapMode: Text.WordWrap
                            renderType: Text.NativeRendering
                        }

                        DyxButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Add your first download"
                            onClicked: root.addNew()
                        }
                    }
                }
            }

            ListView {
                anchors.fill: parent
                anchors.margins: 16
                clip: true
                spacing: 8
                model: downloadsModel
                visible: downloadsModel && downloadsModel.count > 0

                delegate: DownloadItem {
                    width: ListView.view.width
                    downloadId: model.downloadId
                    filename: model.filename
                    url: model.url
                    status: model.status
                    sizeText: model.sizeText || "-- / --"
                    progressText: model.progressText || "0.0%"
                    speedText: model.speedText || ""
                    etaText: model.etaText || ""
                    connectionsText: model.connections + " connections"
                    statusText: model.statusText || ""
                    progressValue: model.progressPercent / 100.0
                    fileType: model.fileType || "other"
                    onTogglePause: root.togglePause(model.downloadId)
                    onRemoveItem: root.removeItem(model.downloadId)
                    onOpenFolder: root.openFolder(model.downloadId)
                }
            }
        }
    }
}
