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
    property string defaultSavePath: settingsModel ? settingsModel.defaultDownloadDir : "~/Downloads"

    Tokens { id: tokens }

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
                Layout.fillHeight: true
                activeFilter: window.activeFilter
                activeCount: backend ? backend.activeCount : 0
                totalCount: backend ? backend.totalCount : 0
                downloadSpeedText: backend ? backend.downloadSpeedText : "0 B/s"
                onFilterSelected: function(filter) {
                    window.activeFilter = filter
                    if (backend) backend.setActiveFilter(filter)
                }
            }

            DownloadArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
        }
    }

    AddDownloadDialog {
        id: addDialog
        hostWindow: window
        defaultSavePath: window.defaultSavePath
        onAddDownload: function(url, connections, savePath) {
            if (backend) backend.startDownload(url, connections, savePath, "")
        }
        onBrowseRequested: function(currentPath) {
            if (backend) {
                const nextPath = backend.pickDirectory(currentPath)
                if (nextPath && nextPath.length > 0) {
                    addDialog.defaultSavePath = nextPath
                }
            }
        }
    }

    Connections {
        target: backend
        function onDirectoryPicked(path) {
            addDialog.defaultSavePath = path
        }
    }
}
