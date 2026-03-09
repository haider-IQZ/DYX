import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "./components"
import "./theme"

ApplicationWindow {
    id: window

    width: 1280
    height: 820
    visible: true
    color: tokens.colors.background
    title: "DYX"
    flags: Qt.Window | Qt.FramelessWindowHint

    property string activeFilter: "all"
    property string activePane: "downloads"
    property string defaultSavePath: settingsModel ? settingsModel.defaultDownloadDir : "~/Downloads"

    Tokens { id: tokens }

    Shortcut {
        context: Qt.ApplicationShortcut
        sequences: ["Ctrl+=", "Ctrl++"]
        onActivated: if (uiState) uiState.zoomIn()
    }

    Shortcut {
        context: Qt.ApplicationShortcut
        sequences: ["Ctrl+-", "Ctrl+_"]
        onActivated: if (uiState) uiState.zoomOut()
    }

    Shortcut {
        context: Qt.ApplicationShortcut
        sequence: "Ctrl+0"
        onActivated: if (uiState) uiState.resetScale()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TitleBar {
            Layout.fillWidth: true
            appWindow: window
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                Layout.preferredWidth: tokens.sidebarWidth
                Layout.minimumWidth: tokens.sidebarWidth
                Layout.maximumWidth: tokens.sidebarWidth
                Layout.fillHeight: true
                activeFilter: window.activeFilter
                settingsActive: window.activePane === "settings"
                activeCount: backend ? backend.activeCount : 0
                totalCount: backend ? backend.totalCount : 0
                downloadSpeedText: backend ? backend.downloadSpeedText : "0 B/s"
                onFilterSelected: function(filter) {
                    window.activePane = "downloads"
                    window.activeFilter = filter
                    if (backend) backend.setActiveFilter(filter)
                }
                onSettingsSelected: window.activePane = "settings"
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: window.activePane === "settings" ? 1 : 0

                DownloadArea {
                    downloadsModel: downloadModel
                    onAddNew: addDialog.open()
                    onTogglePause: function(id) {
                        if (backend) backend.togglePause(id)
                    }
                    onRemoveItem: function(id) {
                        if (backend) backend.deleteItem(id)
                    }
                    onOpenFolder: function(id) {
                        if (backend) backend.openFolder(id)
                    }
                    onSearchChanged: function(query) {
                        if (backend) backend.setSearchQuery(query)
                    }
                }

                SettingsArea {
                    hostWindow: window
                }
            }
        }
    }

    AddDownloadDialog {
        id: addDialog
        hostWindow: window
        defaultSavePath: window.defaultSavePath
        onAddDownload: function(url, savePath) {
            if (backend) {
                const connections = settingsModel ? settingsModel.defaultConnections : 32
                backend.startDownload(url, connections, savePath, "")
            }
        }
    }
}
