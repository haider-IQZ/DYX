import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    property var hostWindow

    color: tokens.colors.background

    readonly property var speedPresets: [
        { id: "slow", label: "Slow", connections: 4, description: "Gentler on weak servers" },
        { id: "medium", label: "Medium", connections: 8, description: "Balanced default" },
        { id: "maximum", label: "Maximum", connections: 32, description: "Fastest possible" }
    ]

    function saveDirectory(path) {
        if (!settingsModel || !backend) {
            return
        }
        settingsModel.defaultDownloadDir = path
        backend.saveSettings()
    }

    function saveConnections(count) {
        if (!settingsModel || !backend) {
            return
        }
        settingsModel.defaultConnections = count
        backend.saveSettings()
    }

    Tokens { id: tokens }

    DirectoryPickerDialog {
        id: directoryPicker
        hostWindow: root.hostWindow
        onPathSelected: function(path) {
            root.saveDirectory(path)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: tokens.contentHeaderHeight
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: tokens.spacing.xl
                anchors.rightMargin: tokens.spacing.xl
                spacing: tokens.spacing.lg

                ColumnLayout {
                    spacing: tokens.px(2)

                    Text {
                        text: "Settings"
                        color: tokens.colors.foreground
                        font.pixelSize: tokens.type.sectionHeading
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: "Defaults for new downloads"
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.bodySmall
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + tokens.spacing.xl
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: contentColumn
                width: Math.min(parent.width - tokens.px(48), tokens.px(680))
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: tokens.spacing.xl
                anchors.topMargin: tokens.spacing.xl
                spacing: tokens.px(18)

                Rectangle {
                    id: directoryCard
                    Layout.fillWidth: true
                    radius: tokens.radiusXl
                    color: tokens.colors.card
                    border.width: 0
                    border.color: "transparent"
                    implicitHeight: directoryContent.implicitHeight + tokens.px(36)

                    ColumnLayout {
                        id: directoryContent
                        anchors.fill: parent
                        anchors.margins: tokens.px(18)
                        spacing: tokens.px(16)

                        ColumnLayout {
                            spacing: tokens.px(4)

                            Text {
                                text: "Default Directory"
                                color: tokens.colors.foreground
                                font.pixelSize: tokens.type.body
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: "New downloads start here unless you pick another folder for that one job."
                                color: tokens.colors.mutedForeground
                                font.pixelSize: tokens.type.caption
                                wrapMode: Text.WordWrap
                                renderType: Text.NativeRendering
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: tokens.radiusLg
                            color: Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.35)
                            implicitHeight: tokens.px(56)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: tokens.px(14)
                                spacing: tokens.px(12)

                                IconGlyph {
                                    iconName: "folder"
                                    iconColor: tokens.colors.primary
                                    font.pixelSize: tokens.px(18)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: settingsModel ? settingsModel.defaultDownloadDir : "~/Downloads"
                                    color: tokens.colors.foreground
                                    font.pixelSize: tokens.type.bodySmall
                                    elide: Text.ElideMiddle
                                    renderType: Text.NativeRendering
                                }

                                DyxButton {
                                    text: "Choose Folder"
                                    borderColor: "transparent"
                                    onClicked: directoryPicker.openAt(settingsModel ? settingsModel.defaultDownloadDir : "")
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: speedCard
                    Layout.fillWidth: true
                    radius: tokens.radiusXl
                    color: tokens.colors.card
                    border.width: 0
                    border.color: "transparent"
                    implicitHeight: speedContent.implicitHeight + tokens.px(36)

                    ColumnLayout {
                        id: speedContent
                        anchors.fill: parent
                        anchors.margins: tokens.px(18)
                        spacing: tokens.px(16)

                        ColumnLayout {
                            spacing: tokens.px(4)

                            Text {
                                text: "Download Speed"
                                color: tokens.colors.foreground
                                font.pixelSize: tokens.type.body
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: "Pick how aggressive DYX should be with parallel connections by default."
                                color: tokens.colors.mutedForeground
                                font.pixelSize: tokens.type.caption
                                wrapMode: Text.WordWrap
                                renderType: Text.NativeRendering
                            }
                        }

                        Repeater {
                            model: root.speedPresets

                            delegate: Button {
                                required property var modelData
                                readonly property bool selected: settingsModel && settingsModel.defaultConnections === modelData.connections

                                Layout.fillWidth: true
                                implicitHeight: tokens.px(56)
                                leftPadding: tokens.px(16)
                                rightPadding: tokens.px(16)
                                hoverEnabled: true

                                background: Rectangle {
                                    radius: tokens.radiusLg
                                    color: parent.selected
                                           ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.12)
                                           : (parent.hovered
                                              ? Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.06)
                                              : Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.28))
                                    border.width: 0
                                    border.color: "transparent"
                                }

                                contentItem: RowLayout {
                                    spacing: tokens.px(14)

                                    Rectangle {
                                        Layout.preferredWidth: tokens.px(28)
                                        Layout.preferredHeight: tokens.px(28)
                                        radius: tokens.px(14)
                                        color: parent.parent.selected
                                               ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.18)
                                               : Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.06)

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: tokens.px(8)
                                            height: tokens.px(8)
                                            radius: tokens.px(4)
                                            color: parent.parent.parent.selected ? tokens.colors.primary : tokens.colors.mutedForeground
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: tokens.px(8)

                                        Text {
                                            text: modelData.label
                                            color: tokens.colors.foreground
                                            font.pixelSize: tokens.type.bodySmall
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.description + " - " + modelData.connections + " connections"
                                            color: tokens.colors.mutedForeground
                                            font.pixelSize: tokens.type.caption
                                            elide: Text.ElideRight
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Text {
                                        text: selected ? "Selected" : ""
                                        color: tokens.colors.primary
                                        font.pixelSize: tokens.type.caption
                                        font.weight: Font.DemiBold
                                        renderType: Text.NativeRendering
                                    }
                                }

                                onClicked: root.saveConnections(modelData.connections)
                            }
                        }

                        Text {
                            text: "Default is Maximum."
                            color: tokens.colors.mutedForeground
                            font.pixelSize: tokens.type.caption
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
