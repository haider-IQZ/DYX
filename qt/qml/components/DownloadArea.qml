import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    property var downloadsModel
    property bool tightLayout: false
    property bool narrowLayout: false
    property string searchQuery: ""
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
            Layout.preferredHeight: headerContent.implicitHeight + tokens.spacing.lg * 2
            color: "transparent"

            ColumnLayout {
                id: headerContent
                anchors.fill: parent
                anchors.leftMargin: tokens.spacing.xl
                anchors.rightMargin: tokens.spacing.xl
                anchors.topMargin: tokens.spacing.lg
                anchors.bottomMargin: tokens.spacing.lg
                spacing: root.tightLayout ? tokens.spacing.sm : tokens.spacing.lg

                RowLayout {
                    id: wideHeaderRow
                    visible: !root.tightLayout
                    Layout.fillWidth: true
                    spacing: tokens.spacing.lg

                    RowLayout {
                        id: titleGroup
                        spacing: tokens.spacing.lg

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
                        text: root.searchQuery
                        Layout.preferredWidth: 256
                        Layout.minimumWidth: 180
                        Layout.maximumWidth: 256
                        leadingIcon: "search"
                        placeholderText: "Search downloads..."
                        onTextChanged: {
                            root.searchQuery = text
                            root.searchChanged(text)
                        }
                    }

                    DyxButton {
                        text: "Add URL"
                        onClicked: root.addNew()
                    }
                }

                RowLayout {
                    visible: root.tightLayout
                    Layout.fillWidth: true
                    spacing: tokens.spacing.lg

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

                RowLayout {
                    visible: root.tightLayout && !root.narrowLayout
                    Layout.fillWidth: true
                    spacing: tokens.spacing.md

                    DyxInput {
                        text: root.searchQuery
                        Layout.fillWidth: true
                        leadingIcon: "search"
                        placeholderText: "Search downloads..."
                        onTextChanged: {
                            root.searchQuery = text
                            root.searchChanged(text)
                        }
                    }

                    DyxButton {
                        text: "Add URL"
                        onClicked: root.addNew()
                    }
                }

                DyxInput {
                    visible: root.narrowLayout
                    text: root.searchQuery
                    Layout.fillWidth: true
                    leadingIcon: "search"
                    placeholderText: "Search downloads..."
                    onTextChanged: {
                        root.searchQuery = text
                        root.searchChanged(text)
                    }
                }

                RowLayout {
                    visible: root.narrowLayout
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    DyxButton {
                        text: "Add URL"
                        onClicked: root.addNew()
                    }
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
                        spacing: tokens.spacing.lg

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tokens.px(64)
                            height: tokens.px(64)
                            radius: width / 2
                            color: tokens.colors.muted

                            IconGlyph {
                                anchors.centerIn: parent
                                iconName: "plus"
                                iconColor: tokens.colors.mutedForeground
                                font.pixelSize: tokens.px(26)
                            }
                        }

                        Item {
                            width: 300
                            implicitHeight: emptyStateTextStack.implicitHeight

                            Column {
                                id: emptyStateTextStack
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: tokens.px(12)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No downloads yet"
                                    color: tokens.colors.foreground
                                    font.pixelSize: tokens.px(18)
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    width: 260
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Click \"Add URL\" to start downloading files"
                                    color: tokens.colors.mutedForeground
                                    font.pixelSize: tokens.type.bodySmall
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width
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
                }
            }

            ListView {
                anchors.fill: parent
                anchors.margins: tokens.spacing.lg
                clip: true
                spacing: tokens.spacing.sm
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
