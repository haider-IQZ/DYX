import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    property string activeFilter: "all"
    property int activeCount: 0
    property int totalCount: 0
    property string downloadSpeedText: "0 B/s"
    signal filterSelected(string filter)

    width: tokens.sidebarWidth
    color: tokens.colors.card

    Tokens { id: tokens }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 176
            color: "transparent"
            border.width: 0

            Rectangle {
                anchors.fill: parent
                anchors.margins: 16
                radius: tokens.radiusXl
                color: Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.5)
                border.width: 1
                border.color: tokens.colors.border

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Repeater {
                        model: [
                            { icon: "activity", label: "Active", value: root.activeCount + " downloads", bg: Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.2), fg: tokens.colors.primary },
                            { icon: "harddrive", label: "Total", value: root.totalCount + " files", bg: Qt.rgba(tokens.colors.green.r, tokens.colors.green.g, tokens.colors.green.b, 0.2), fg: tokens.colors.green },
                            { icon: "arrowdown", label: "Speed", value: root.downloadSpeedText, bg: Qt.rgba(tokens.colors.blue.r, tokens.colors.blue.g, tokens.colors.blue.b, 0.2), fg: tokens.colors.blue }
                        ]

                        delegate: RowLayout {
                            required property var modelData
                            spacing: 12
                            width: parent.width

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: tokens.radiusLg
                                color: modelData.bg

                                IconGlyph {
                                    anchors.centerIn: parent
                                    iconName: modelData.icon
                                    iconColor: modelData.fg
                                    font.pixelSize: 16
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.label
                                    color: tokens.colors.mutedForeground
                                    font.pixelSize: tokens.type.caption
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: modelData.value
                                    color: tokens.colors.foreground
                                    font.pixelSize: tokens.type.bodySmall
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    renderType: Text.NativeRendering
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                Text {
                    text: "STATUS"
                    color: tokens.colors.mutedForeground
                    font.pixelSize: tokens.type.micro
                    font.letterSpacing: 1.2
                    renderType: Text.NativeRendering
                }

                DyxSidebarItem { text: "All Downloads"; iconName: "download"; active: root.activeFilter === "all"; onClicked: root.filterSelected("all") }
                DyxSidebarItem { text: "Downloading"; iconName: "activity"; active: root.activeFilter === "downloading"; onClicked: root.filterSelected("downloading") }
                DyxSidebarItem { text: "Completed"; iconName: "check"; active: root.activeFilter === "completed"; onClicked: root.filterSelected("completed") }
                DyxSidebarItem { text: "Queued"; iconName: "clock"; active: root.activeFilter === "queued"; onClicked: root.filterSelected("queued") }

                Item { height: 16; width: 1 }

                Text {
                    text: "CATEGORIES"
                    color: tokens.colors.mutedForeground
                    font.pixelSize: tokens.type.micro
                    font.letterSpacing: 1.2
                    renderType: Text.NativeRendering
                }

                DyxSidebarItem { text: "Archives"; iconName: "archive"; active: root.activeFilter === "archives"; onClicked: root.filterSelected("archives") }
                DyxSidebarItem { text: "Videos"; iconName: "video"; active: root.activeFilter === "videos"; onClicked: root.filterSelected("videos") }
                DyxSidebarItem { text: "Audio"; iconName: "audio"; active: root.activeFilter === "audio"; onClicked: root.filterSelected("audio") }
                DyxSidebarItem { text: "Documents"; iconName: "document"; active: root.activeFilter === "documents"; onClicked: root.filterSelected("documents") }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            color: "transparent"
            border.width: 0

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: tokens.colors.border
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: "Powered by"
                    color: tokens.colors.mutedForeground
                    font.pixelSize: tokens.type.micro
                    horizontalAlignment: Text.AlignHCenter
                    width: 120
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "axel"
                    color: tokens.colors.foreground
                    font.pixelSize: tokens.type.bodySmall
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    width: 120
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: tokens.colors.border
    }
}
