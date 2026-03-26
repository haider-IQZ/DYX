import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme"

Rectangle {
    id: root

    property var hostWindow
    property bool tightLayout: false
    property bool narrowLayout: false
    readonly property bool stackedRows: root.narrowLayout || contentColumn.width < tokens.px(760)
    readonly property int labelWidth: root.stackedRows ? 0 : tokens.px(root.tightLayout ? 190 : 230)
    readonly property color surface: Qt.rgba(tokens.colors.muted.r, tokens.colors.muted.g, tokens.colors.muted.b, 0.72)
    readonly property color surfaceBorder: Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.06)
    readonly property color rowDivider: Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.07)
    readonly property color textPrimary: tokens.colors.foreground
    readonly property color textSecondary: tokens.colors.mutedForeground
    readonly property color controlFill: Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.06)
    readonly property color controlSelectedFill: Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.14)
    readonly property color controlSelectedBorder: Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.16)
    readonly property color fieldFill: Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.04)

    color: tokens.colors.background

    readonly property var speedPresets: [
        { id: "slow", label: "Slow", connections: 4 },
        { id: "medium", label: "Medium", connections: 8 },
        { id: "maximum", label: "Max", connections: 32 }
    ]
    readonly property var retryPresets: [
        { id: "off", label: "Off", retries: 0 },
        { id: "one", label: "1", retries: 1 },
        { id: "two", label: "2", retries: 2 },
        { id: "three", label: "3", retries: 3 },
        { id: "four", label: "4", retries: 4 },
        { id: "five", label: "5", retries: 5 },
        { id: "infinite", label: "", retries: -1, iconName: "infinity" }
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

    function saveRetryLimit(limit) {
        if (!settingsModel || !backend) {
            return
        }
        settingsModel.autoRetryLimit = limit
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
                width: Math.max(0, Math.min(parent.width - (tokens.spacing.xl * 2), tokens.px(760)))
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: tokens.spacing.xl
                anchors.topMargin: tokens.spacing.xl
                spacing: tokens.px(12)

                Text {
                    text: "DOWNLOADS"
                    color: tokens.colors.mutedForeground
                    font.pixelSize: tokens.type.micro
                    font.letterSpacing: 1.2
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: tokens.px(18)
                    color: root.surface
                    border.width: 1
                    border.color: root.surfaceBorder
                    implicitHeight: groupContent.implicitHeight + tokens.px(8)

                    ColumnLayout {
                        id: groupContent
                        anchors.fill: parent
                        anchors.margins: tokens.px(4)
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: directoryRow.implicitHeight + tokens.px(24)

                            ColumnLayout {
                                id: directoryRow
                                anchors.fill: parent
                                anchors.margins: tokens.px(16)
                                spacing: root.stackedRows ? tokens.px(14) : 0

                                RowLayout {
                                    visible: !root.stackedRows
                                    Layout.fillWidth: true
                                    spacing: tokens.px(18)

                                    ColumnLayout {
                                        Layout.preferredWidth: root.labelWidth
                                        Layout.maximumWidth: root.labelWidth
                                        Layout.fillWidth: root.narrowLayout
                                        spacing: tokens.px(4)

                                        Text {
                                            text: "Default Directory"
                                            color: root.textPrimary
                                            font.pixelSize: tokens.type.body
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            text: "New downloads start here unless you pick another folder for one job."
                                            color: root.textSecondary
                                            font.pixelSize: tokens.type.caption
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: tokens.px(10)

                                        Button {
                                            Layout.fillWidth: true
                                            implicitHeight: tokens.px(40)
                                            leftPadding: tokens.px(14)
                                            rightPadding: tokens.px(14)
                                            topPadding: 0
                                            bottomPadding: 0
                                            hoverEnabled: true

                                            background: Rectangle {
                                                radius: tokens.px(10)
                                                color: parent.down
                                                       ? Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.08)
                                                       : (parent.hovered ? Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.06) : root.fieldFill)
                                                border.width: 1
                                                border.color: Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.08)
                                            }

                                            contentItem: RowLayout {
                                                spacing: tokens.px(10)

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: settingsModel ? settingsModel.defaultDownloadDir : "~/Downloads"
                                                    color: root.textPrimary
                                                    font.pixelSize: tokens.type.bodySmall
                                                    elide: Text.ElideMiddle
                                                    renderType: Text.NativeRendering
                                                }

                                                Text {
                                                    text: ">"
                                                    color: root.textSecondary
                                                    font.pixelSize: tokens.type.body
                                                    font.weight: Font.Medium
                                                    renderType: Text.NativeRendering
                                                }
                                            }

                                            onClicked: directoryPicker.openAt(settingsModel ? settingsModel.defaultDownloadDir : "")
                                        }
                                    }
                                }

                                ColumnLayout {
                                    visible: root.stackedRows
                                    Layout.fillWidth: true
                                    spacing: tokens.px(14)

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: tokens.px(4)

                                        Text {
                                            text: "Default Directory"
                                            color: root.textPrimary
                                            font.pixelSize: tokens.type.body
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            text: "New downloads start here unless you pick another folder for one job."
                                            color: root.textSecondary
                                            font.pixelSize: tokens.type.caption
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Button {
                                        Layout.fillWidth: true
                                        implicitHeight: tokens.px(40)
                                        leftPadding: tokens.px(14)
                                        rightPadding: tokens.px(14)
                                        topPadding: 0
                                        bottomPadding: 0
                                        hoverEnabled: true

                                        background: Rectangle {
                                            radius: tokens.px(10)
                                            color: parent.down
                                                   ? Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.08)
                                                   : (parent.hovered ? Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.06) : root.fieldFill)
                                            border.width: 1
                                            border.color: Qt.rgba(tokens.colors.foreground.r, tokens.colors.foreground.g, tokens.colors.foreground.b, 0.08)
                                        }

                                        contentItem: RowLayout {
                                            spacing: tokens.px(10)

                                            Text {
                                                Layout.fillWidth: true
                                                text: settingsModel ? settingsModel.defaultDownloadDir : "~/Downloads"
                                                color: root.textPrimary
                                                font.pixelSize: tokens.type.bodySmall
                                                elide: Text.ElideMiddle
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                text: ">"
                                                color: root.textSecondary
                                                font.pixelSize: tokens.type.body
                                                font.weight: Font.Medium
                                                renderType: Text.NativeRendering
                                            }
                                        }

                                        onClicked: directoryPicker.openAt(settingsModel ? settingsModel.defaultDownloadDir : "")
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.rowDivider
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: speedRow.implicitHeight + tokens.px(22)

                            ColumnLayout {
                                id: speedRow
                                anchors.fill: parent
                                anchors.margins: tokens.px(16)
                                spacing: root.stackedRows ? tokens.px(14) : 0

                                RowLayout {
                                    visible: !root.stackedRows
                                    Layout.fillWidth: true
                                    spacing: tokens.px(18)

                                    ColumnLayout {
                                        Layout.preferredWidth: root.labelWidth
                                        Layout.maximumWidth: root.labelWidth
                                        Layout.fillWidth: root.narrowLayout
                                        spacing: tokens.px(4)

                                        Text {
                                            text: "Download Speed"
                                            color: root.textPrimary
                                            font.pixelSize: tokens.type.body
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            text: "Parallel connections per download."
                                            color: root.textSecondary
                                            font.pixelSize: tokens.type.caption
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: true
                                        radius: tokens.px(11)
                                        color: root.controlFill
                                        implicitHeight: tokens.px(36)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: tokens.px(3)
                                            spacing: tokens.px(4)

                                            Repeater {
                                                model: root.speedPresets

                                                delegate: Button {
                                                    required property var modelData
                                                    readonly property bool selected: settingsModel && settingsModel.defaultConnections === modelData.connections

                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: modelData.label === "Medium" ? tokens.px(94) : tokens.px(78)
                                                    implicitHeight: tokens.px(30)
                                                    leftPadding: 0
                                                    rightPadding: 0
                                                    topPadding: 0
                                                    bottomPadding: 0
                                                    hoverEnabled: true

                                                    background: Rectangle {
                                                        radius: tokens.px(9)
                                                        color: parent.selected ? root.controlSelectedFill : "transparent"
                                                        border.width: parent.selected ? 1 : 0
                                                        border.color: root.controlSelectedBorder
                                                    }

                                                    contentItem: Text {
                                                        text: parent.modelData.label
                                                        color: parent.selected ? root.textPrimary : root.textSecondary
                                                        font.pixelSize: tokens.type.caption
                                                        font.weight: parent.selected ? Font.Medium : Font.Normal
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        renderType: Text.NativeRendering
                                                    }

                                                    onClicked: root.saveConnections(modelData.connections)
                                                }
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    visible: root.stackedRows
                                    Layout.fillWidth: true
                                    spacing: tokens.px(14)

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: tokens.px(4)

                                        Text {
                                            text: "Download Speed"
                                            color: root.textPrimary
                                            font.pixelSize: tokens.type.body
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            text: "Parallel connections per download."
                                            color: root.textSecondary
                                            font.pixelSize: tokens.type.caption
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        radius: tokens.px(11)
                                        color: root.controlFill
                                        implicitHeight: tokens.px(36)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: tokens.px(3)
                                            spacing: tokens.px(4)

                                            Repeater {
                                                model: root.speedPresets

                                                delegate: Button {
                                                    required property var modelData
                                                    readonly property bool selected: settingsModel && settingsModel.defaultConnections === modelData.connections

                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: modelData.label === "Medium" ? tokens.px(94) : tokens.px(78)
                                                    implicitHeight: tokens.px(30)
                                                    leftPadding: 0
                                                    rightPadding: 0
                                                    topPadding: 0
                                                    bottomPadding: 0
                                                    hoverEnabled: true

                                                    background: Rectangle {
                                                        radius: tokens.px(9)
                                                        color: parent.selected ? root.controlSelectedFill : "transparent"
                                                        border.width: parent.selected ? 1 : 0
                                                        border.color: root.controlSelectedBorder
                                                    }

                                                    contentItem: Text {
                                                        text: parent.modelData.label
                                                        color: parent.selected ? root.textPrimary : root.textSecondary
                                                        font.pixelSize: tokens.type.caption
                                                        font.weight: parent.selected ? Font.Medium : Font.Normal
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        renderType: Text.NativeRendering
                                                    }

                                                    onClicked: root.saveConnections(modelData.connections)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.rowDivider
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: retryRow.implicitHeight + tokens.px(22)

                            ColumnLayout {
                                id: retryRow
                                anchors.fill: parent
                                anchors.margins: tokens.px(16)
                                spacing: root.stackedRows ? tokens.px(14) : 0

                                RowLayout {
                                    visible: !root.stackedRows
                                    Layout.fillWidth: true
                                    spacing: tokens.px(18)

                                    ColumnLayout {
                                        Layout.preferredWidth: root.labelWidth
                                        Layout.maximumWidth: root.labelWidth
                                        Layout.fillWidth: root.narrowLayout
                                        spacing: tokens.px(4)

                                        Text {
                                            text: "Retry After Failure"
                                            color: root.textPrimary
                                            font.pixelSize: tokens.type.body
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            text: "How many times DYX retries before it gives up."
                                            color: root.textSecondary
                                            font.pixelSize: tokens.type.caption
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: true
                                        radius: tokens.px(11)
                                        color: root.controlFill
                                        implicitHeight: tokens.px(36)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: tokens.px(3)
                                            spacing: tokens.px(4)

                                            Repeater {
                                                model: root.retryPresets

                                                delegate: Button {
                                                    required property var modelData
                                                    readonly property bool selected: settingsModel && settingsModel.autoRetryLimit === modelData.retries

                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: modelData.label === "Off" ? tokens.px(70) : tokens.px(42)
                                                    implicitHeight: tokens.px(30)
                                                    leftPadding: 0
                                                    rightPadding: 0
                                                    topPadding: 0
                                                    bottomPadding: 0
                                                    hoverEnabled: true

                                                    background: Rectangle {
                                                        radius: tokens.px(9)
                                                        color: parent.selected ? root.controlSelectedFill : "transparent"
                                                        border.width: parent.selected ? 1 : 0
                                                        border.color: root.controlSelectedBorder
                                                    }

                                                    contentItem: Text {
                                                        visible: !modelData.iconName
                                                        text: modelData.label
                                                        color: parent.selected ? root.textPrimary : root.textSecondary
                                                        font.pixelSize: tokens.type.caption
                                                        font.weight: parent.selected ? Font.Medium : Font.Normal
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        renderType: Text.NativeRendering
                                                    }

                                                    IconGlyph {
                                                        anchors.centerIn: parent
                                                        visible: !!modelData.iconName
                                                        iconName: modelData.iconName || ""
                                                        iconColor: parent.selected ? root.textPrimary : root.textSecondary
                                                        font.pixelSize: tokens.px(16)
                                                    }

                                                    onClicked: root.saveRetryLimit(modelData.retries)
                                                }
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    visible: root.stackedRows
                                    Layout.fillWidth: true
                                    spacing: tokens.px(14)

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: tokens.px(4)

                                        Text {
                                            text: "Retry After Failure"
                                            color: root.textPrimary
                                            font.pixelSize: tokens.type.body
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            text: "How many times DYX retries before it gives up."
                                            color: root.textSecondary
                                            font.pixelSize: tokens.type.caption
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        radius: tokens.px(11)
                                        color: root.controlFill
                                        implicitHeight: tokens.px(36)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: tokens.px(3)
                                            spacing: tokens.px(4)

                                            Repeater {
                                                model: root.retryPresets

                                                delegate: Button {
                                                    required property var modelData
                                                    readonly property bool selected: settingsModel && settingsModel.autoRetryLimit === modelData.retries

                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: modelData.label === "Off" ? tokens.px(70) : tokens.px(42)
                                                    implicitHeight: tokens.px(30)
                                                    leftPadding: 0
                                                    rightPadding: 0
                                                    topPadding: 0
                                                    bottomPadding: 0
                                                    hoverEnabled: true

                                                    background: Rectangle {
                                                        radius: tokens.px(9)
                                                        color: parent.selected ? root.controlSelectedFill : "transparent"
                                                        border.width: parent.selected ? 1 : 0
                                                        border.color: root.controlSelectedBorder
                                                    }

                                                    contentItem: Text {
                                                        visible: !modelData.iconName
                                                        text: modelData.label
                                                        color: parent.selected ? root.textPrimary : root.textSecondary
                                                        font.pixelSize: tokens.type.caption
                                                        font.weight: parent.selected ? Font.Medium : Font.Normal
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        renderType: Text.NativeRendering
                                                    }

                                                    IconGlyph {
                                                        anchors.centerIn: parent
                                                        visible: !!modelData.iconName
                                                        iconName: modelData.iconName || ""
                                                        iconColor: parent.selected ? root.textPrimary : root.textSecondary
                                                        font.pixelSize: tokens.px(16)
                                                    }

                                                    onClicked: root.saveRetryLimit(modelData.retries)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
