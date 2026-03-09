import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

DyxCard {
    id: root

    property string downloadId: ""
    property string filename: ""
    property string url: ""
    property string status: "queued"
    property string sizeText: "-- / --"
    property string progressText: "0.0%"
    property string speedText: ""
    property string etaText: ""
    property string connectionsText: ""
    property string statusText: ""
    property real progressValue: 0
    property string fileType: "other"

    signal togglePause(string id)
    signal removeItem(string id)
    signal openFolder(string id)
    readonly property int actionSpacing: tokens.px(4)
    readonly property int actionTrayWidth: (tokens.iconButtonSize * 3) + (actionSpacing * 2)
    readonly property bool canTogglePause: root.status === "downloading" || root.status === "paused"

    height: tokens.px(116)
    hovered: cardHover.hovered || actionRow.hovered

    Tokens { id: tokens }

    function iconNameForType(type) {
        if (type === "archive") return "archive"
        if (type === "video") return "video"
        if (type === "audio") return "audio"
        if (type === "document") return "document"
        if (type === "image") return "image"
        return "file"
    }

    function statusColor() {
        if (root.status === "completed") return tokens.colors.green
        if (root.status === "downloading") return tokens.colors.blue
        if (root.status === "paused") return tokens.colors.yellow
        if (root.status === "error") return tokens.colors.red
        return tokens.colors.mutedForeground
    }

    function statusIconName() {
        if (root.status === "completed") return "check"
        if (root.status === "queued") return "clock"
        if (root.status === "error") return "close"
        return ""
    }

    function progressColor() {
        if (root.status === "completed") return "#22c55e"
        if (root.status === "downloading") return tokens.colors.primary
        if (root.status === "paused") return "#eab308"
        return tokens.colors.mutedForeground
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 0
    }

    HoverHandler {
        id: cardHover
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: tokens.px(16)
        spacing: tokens.px(16)

        Rectangle {
            Layout.preferredWidth: tokens.cardIconSize
            Layout.preferredHeight: tokens.cardIconSize
            radius: tokens.radiusXl
            color: root.status === "completed" ? Qt.rgba(tokens.colors.green.r, tokens.colors.green.g, tokens.colors.green.b, 0.2) : tokens.colors.muted

            IconGlyph {
                anchors.centerIn: parent
                iconName: root.iconNameForType(root.fileType)
                iconColor: root.status === "completed" ? tokens.colors.green : tokens.colors.mutedForeground
                font.pixelSize: tokens.px(22)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: tokens.px(16)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.filename
                        color: tokens.colors.foreground
                        font.pixelSize: tokens.type.body
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: root.url
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.caption
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        renderType: Text.NativeRendering
                    }
                }

                Item {
                    Layout.preferredWidth: root.actionTrayWidth
                    Layout.minimumWidth: root.actionTrayWidth
                    Layout.maximumWidth: root.actionTrayWidth
                    implicitHeight: tokens.iconButtonSize

                    RowLayout {
                        id: actionRow
                        property bool hovered: pauseButton.hovered || folderButton.hovered || deleteButton.hovered
                        anchors.fill: parent
                        spacing: root.actionSpacing
                        opacity: root.hovered ? 1 : 0
                        enabled: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: tokens.motionBase } }

                        Item {
                            Layout.preferredWidth: tokens.iconButtonSize
                            Layout.preferredHeight: tokens.iconButtonSize

                            DyxIconButton {
                                id: pauseButton
                                anchors.fill: parent
                                visible: root.canTogglePause
                                enabled: root.canTogglePause && actionRow.enabled
                                iconName: root.status === "downloading" ? "pause" : "play"
                                fillColor: "transparent"
                                strokeColor: "transparent"
                                onClicked: root.togglePause(root.downloadId)
                            }
                        }

                        DyxIconButton {
                            id: folderButton
                            iconName: "folder"
                            fillColor: "transparent"
                            strokeColor: "transparent"
                            enabled: actionRow.enabled
                            onClicked: root.openFolder(root.downloadId)
                        }

                        DyxIconButton {
                            id: deleteButton
                            iconName: "trash"
                            iconColor: tokens.colors.red
                            fillColor: "transparent"
                            strokeColor: "transparent"
                            enabled: actionRow.enabled
                            onClicked: root.removeItem(root.downloadId)
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: tokens.px(12) }

            DyxProgressBar {
                Layout.fillWidth: true
                value: root.progressValue
                fillColor: root.progressColor()
            }

            Item { Layout.preferredHeight: tokens.px(8) }

            RowLayout {
                Layout.fillWidth: true
                spacing: tokens.px(12)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: tokens.px(12)

                    Text {
                        text: root.sizeText
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.caption
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: root.progressText
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.caption
                        renderType: Text.NativeRendering
                    }

                    Text {
                        visible: root.speedText.length > 0
                        text: root.speedText
                        color: tokens.colors.blue
                        font.pixelSize: tokens.type.caption
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    Text {
                        visible: root.etaText.length > 0
                        Layout.fillWidth: true
                        text: "ETA: " + root.etaText
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.caption
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    id: statusMetaRow
                    Layout.preferredWidth: implicitWidth
                    Layout.minimumWidth: implicitWidth
                    spacing: tokens.px(8)

                    IconGlyph {
                        visible: root.statusIconName().length > 0
                        iconName: root.statusIconName()
                        iconColor: root.statusColor()
                        font.pixelSize: tokens.px(14)
                    }

                    Text {
                        text: root.statusText.length > 0 ? root.statusText : root.status
                        color: root.statusColor()
                        font.pixelSize: tokens.type.caption
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: root.connectionsText
                        color: tokens.colors.mutedForeground
                        font.pixelSize: tokens.type.caption
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
