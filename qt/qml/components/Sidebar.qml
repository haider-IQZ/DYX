import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    property string activeFilter: "all"
    property bool settingsActive: false
    property bool compactMode: false
    property int activeCount: 0
    property int totalCount: 0
    property string downloadSpeedText: "0 B/s"
    signal filterSelected(string filter)
    signal settingsSelected()

    width: compactMode ? tokens.sidebarCompactWidth : tokens.sidebarExpandedWidth
    implicitWidth: width
    color: tokens.colors.card

    Tokens { id: tokens }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: statsSection
            visible: !root.compactMode
            Layout.fillWidth: true
            Layout.preferredHeight: root.compactMode ? 0 : statsCard.implicitHeight + tokens.spacing.lg * 2
            color: "transparent"
            border.width: 0

            Rectangle {
                id: statsCard
                anchors.fill: parent
                anchors.margins: tokens.spacing.lg
                radius: tokens.radiusXl
                color: Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.5)
                border.width: 0
                border.color: "transparent"
                implicitHeight: statsContent.implicitHeight + tokens.spacing.lg * 2

                Column {
                    id: statsContent
                    anchors.fill: parent
                    anchors.margins: tokens.spacing.lg
                    spacing: tokens.px(14)

                    Repeater {
                        model: [
                            { icon: "activity", label: "Active", value: root.activeCount + " downloads", bg: Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.2), fg: tokens.colors.primary },
                            { icon: "harddrive", label: "Total", value: root.totalCount + " files", bg: Qt.rgba(tokens.colors.green.r, tokens.colors.green.g, tokens.colors.green.b, 0.2), fg: tokens.colors.green },
                            { icon: "arrowdown", label: "Speed", value: root.downloadSpeedText, bg: Qt.rgba(tokens.colors.blue.r, tokens.colors.blue.g, tokens.colors.blue.b, 0.2), fg: tokens.colors.blue }
                        ]

                        delegate: RowLayout {
                            required property var modelData
                            spacing: tokens.px(12)
                            width: parent.width

                            Rectangle {
                                Layout.preferredWidth: tokens.statsIconSize
                                Layout.preferredHeight: tokens.statsIconSize
                                radius: tokens.radiusLg
                                color: modelData.bg

                                IconGlyph {
                                    anchors.centerIn: parent
                                    iconName: modelData.icon
                                    iconColor: modelData.fg
                                    font.pixelSize: tokens.px(16)
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

            Flickable {
                anchors.fill: parent
                anchors.margins: root.compactMode ? tokens.spacing.sm : tokens.spacing.md
                contentWidth: width
                contentHeight: navColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: navColumn
                    width: parent.width
                    spacing: tokens.px(4)

                    Text {
                        visible: !root.compactMode
                        text: "STATUS"
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.micro
                        font.letterSpacing: 1.2
                        renderType: Text.NativeRendering
                    }

                    DyxSidebarItem { width: parent.width; compactMode: root.compactMode; text: "All Downloads"; iconName: "download"; active: !root.settingsActive && root.activeFilter === "all"; onClicked: root.filterSelected("all") }
                    DyxSidebarItem { width: parent.width; compactMode: root.compactMode; text: "Downloading"; iconName: "activity"; active: !root.settingsActive && root.activeFilter === "downloading"; onClicked: root.filterSelected("downloading") }
                    DyxSidebarItem { width: parent.width; compactMode: root.compactMode; text: "Completed"; iconName: "check"; active: !root.settingsActive && root.activeFilter === "completed"; onClicked: root.filterSelected("completed") }
                    DyxSidebarItem { width: parent.width; compactMode: root.compactMode; text: "Queued"; iconName: "clock"; active: !root.settingsActive && root.activeFilter === "queued"; onClicked: root.filterSelected("queued") }

                    Item { height: tokens.spacing.lg; width: 1 }

                    Text {
                        visible: !root.compactMode
                        text: "CATEGORIES"
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.micro
                        font.letterSpacing: 1.2
                        renderType: Text.NativeRendering
                    }

                    DyxSidebarItem { width: parent.width; compactMode: root.compactMode; text: "Archives"; iconName: "archive"; active: !root.settingsActive && root.activeFilter === "archives"; onClicked: root.filterSelected("archives") }
                    DyxSidebarItem { width: parent.width; compactMode: root.compactMode; text: "Videos"; iconName: "video"; active: !root.settingsActive && root.activeFilter === "videos"; onClicked: root.filterSelected("videos") }
                    DyxSidebarItem { width: parent.width; compactMode: root.compactMode; text: "Audio"; iconName: "audio"; active: !root.settingsActive && root.activeFilter === "audio"; onClicked: root.filterSelected("audio") }
                    DyxSidebarItem { width: parent.width; compactMode: root.compactMode; text: "Documents"; iconName: "document"; active: !root.settingsActive && root.activeFilter === "documents"; onClicked: root.filterSelected("documents") }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: tokens.px(72)
            color: "transparent"
            border.width: 0

            DyxSidebarItem {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: tokens.spacing.md
                anchors.rightMargin: tokens.spacing.md
                compactMode: root.compactMode
                text: "Settings"
                iconName: "gear"
                active: root.settingsActive
                onClicked: root.settingsSelected()
            }
        }
    }

}
