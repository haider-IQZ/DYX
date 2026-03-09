import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

DyxDialog {
    id: root

    property string currentPath: ""
    property string navigatedPath: ""
    property string searchQuery: ""
    property var navigationHistory: []
    property int navigationIndex: -1
    property var entries: []
    readonly property bool canGoBack: root.navigationIndex > 0
    readonly property bool canGoForward: root.navigationIndex >= 0 && root.navigationIndex < root.navigationHistory.length - 1
    readonly property var filteredEntries: {
        const query = root.searchQuery.trim().toLowerCase()
        if (!query.length) {
            return root.entries
        }

        return root.entries.filter(function(entry) {
            return entry.name.toLowerCase().indexOf(query) !== -1
                || entry.path.toLowerCase().indexOf(query) !== -1
        })
    }
    signal pathSelected(string path)

    dialogWidth: 720

    Tokens { id: tokens }

    function refresh() {
        if (!backend) {
            entries = []
            return
        }
        navigatedPath = backend.normalizeDirectoryPath(navigatedPath)
        entries = backend.listDirectories(navigatedPath)
    }

    function resetHistory(path) {
        root.navigationHistory = [path]
        root.navigationIndex = 0
    }

    function pushHistory(path) {
        const history = root.navigationHistory.slice(0, root.navigationIndex + 1)
        if (history.length > 0 && history[history.length - 1] === path) {
            root.navigationHistory = history
            root.navigationIndex = history.length - 1
            return
        }

        history.push(path)
        root.navigationHistory = history
        root.navigationIndex = history.length - 1
    }

    function navigateTo(path, remember) {
        const normalized = backend ? backend.normalizeDirectoryPath(path) : path
        root.searchQuery = ""
        root.navigatedPath = normalized
        if (remember === false) {
            root.refresh()
            return
        }
        root.pushHistory(normalized)
        root.refresh()
    }

    function goBack() {
        if (!root.canGoBack) {
            return
        }
        root.navigationIndex = root.navigationIndex - 1
        root.searchQuery = ""
        root.navigatedPath = root.navigationHistory[root.navigationIndex]
        root.refresh()
    }

    function goForward() {
        if (!root.canGoForward) {
            return
        }
        root.navigationIndex = root.navigationIndex + 1
        root.searchQuery = ""
        root.navigatedPath = root.navigationHistory[root.navigationIndex]
        root.refresh()
    }

    function openAt(path) {
        const normalized = backend ? backend.normalizeDirectoryPath(path) : path
        root.searchQuery = ""
        root.navigatedPath = normalized
        root.resetHistory(normalized)
        root.refresh()
        open()
    }

    onOpened: refresh()

    ColumnLayout {
        width: root.dialogWidth
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            Layout.bottomMargin: 0
            spacing: 12

            ColumnLayout {
                spacing: 2

                Text {
                    text: "Choose Folder"
                    color: tokens.colors.foreground
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Text {
                    text: root.navigatedPath
                    color: tokens.colors.mutedForeground
                    font.pixelSize: tokens.type.caption
                    renderType: Text.NativeRendering
                }
            }

            Item { Layout.fillWidth: true }

            DyxIconButton {
                iconName: "close"
                fillColor: "transparent"
                strokeColor: "transparent"
                onClicked: root.close()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                DyxButton {
                    text: "<"
                    ghost: true
                    fillColor: "transparent"
                    borderColor: "transparent"
                    labelColor: tokens.colors.foreground
                    enabled: root.canGoBack
                    implicitWidth: 40
                    onClicked: root.goBack()
                }

                DyxButton {
                    text: ">"
                    ghost: true
                    fillColor: "transparent"
                    borderColor: "transparent"
                    labelColor: tokens.colors.foreground
                    enabled: root.canGoForward
                    implicitWidth: 40
                    onClicked: root.goForward()
                }

                DyxButton {
                    text: "Home"
                    ghost: true
                    fillColor: "transparent"
                    borderColor: "transparent"
                    labelColor: tokens.colors.foreground
                    onClicked: root.navigateTo(backend ? backend.homeDirectory() : root.navigatedPath)
                }

                DyxButton {
                    text: "Up"
                    ghost: true
                    fillColor: "transparent"
                    borderColor: "transparent"
                    labelColor: tokens.colors.foreground
                    onClicked: root.navigateTo(backend ? backend.parentDirectory(root.navigatedPath) : root.navigatedPath)
                }

                Item { Layout.fillWidth: true }

                DyxButton {
                    text: "Use This Folder"
                    borderColor: "transparent"
                    onClicked: {
                        root.pathSelected(root.navigatedPath)
                        root.close()
                    }
                }
            }

            DyxInput {
                id: searchInput
                Layout.fillWidth: true
                leadingIcon: "search"
                placeholderText: "Search directories..."
                text: root.searchQuery
                onTextChanged: root.searchQuery = text
            }

            Rectangle {
                Layout.fillWidth: true
                radius: tokens.radiusLg
                color: Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.45)
                border.width: 0
                implicitHeight: 54

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 10
                        color: Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.14)

                        IconGlyph {
                            anchors.centerIn: parent
                            iconName: "folder"
                            iconColor: tokens.colors.primary
                            font.pixelSize: 18
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Current folder"
                            color: tokens.colors.mutedForeground
                            font.pixelSize: tokens.type.micro
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: root.navigatedPath
                            color: tokens.colors.foreground
                            font.pixelSize: tokens.type.bodySmall
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 360
                radius: tokens.radiusXl
                color: Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.25)
                border.width: 0

                Loader {
                    anchors.fill: parent
                    active: root.filteredEntries.length === 0
                    sourceComponent: Item {
                        Column {
                            anchors.centerIn: parent
                            spacing: 12

                            IconGlyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                iconName: "folder"
                                iconColor: tokens.colors.mutedForeground
                                font.pixelSize: 28
                            }

                            Text {
                                text: root.searchQuery.trim().length > 0 ? "No matches found" : "No folders here"
                                color: tokens.colors.foreground
                                font.pixelSize: tokens.type.body
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                width: 200
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: root.searchQuery.trim().length > 0
                                      ? "Try a different search or go up a level."
                                      : "Try going up a level or choose this folder directly."
                                color: tokens.colors.mutedForeground
                                font.pixelSize: tokens.type.caption
                                horizontalAlignment: Text.AlignHCenter
                                width: 260
                                wrapMode: Text.WordWrap
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                ListView {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    spacing: 6
                    model: root.filteredEntries
                    visible: root.filteredEntries.length > 0

                    delegate: Button {
                        required property var modelData

                        width: ListView.view.width
                        height: 56
                        hoverEnabled: true
                        leftPadding: 14
                        rightPadding: 14

                        background: Rectangle {
                            radius: tokens.radiusLg
                            color: parent.hovered
                                   ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.12)
                                   : "transparent"
                            border.width: 0
                        }

                        contentItem: RowLayout {
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 11
                                color: Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.12)

                                IconGlyph {
                                    anchors.centerIn: parent
                                    iconName: "folder"
                                    iconColor: tokens.colors.primary
                                    font.pixelSize: 18
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name
                                    color: tokens.colors.foreground
                                    font.pixelSize: tokens.type.bodySmall
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: modelData.path
                                    color: tokens.colors.mutedForeground
                                    font.pixelSize: tokens.type.caption
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                    renderType: Text.NativeRendering
                                }
                            }

                            IconGlyph {
                                iconName: "play"
                                iconColor: tokens.colors.mutedForeground
                                font.pixelSize: 12
                                rotation: 0
                            }
                        }

                        onClicked: {
                            root.navigateTo(modelData.path)
                        }
                    }
                }
            }
        }
    }
}
