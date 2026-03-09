import QtQuick 2.15
import "../theme"

Item {
    id: root

    Tokens { id: tokens }

    property string iconName: "file"
    property color iconColor: "#fbfbfb"
    property real strokeWidth: 1.8
    property alias font: fallback.font

    implicitWidth: Math.max(16, fallback.font.pixelSize + 2)
    implicitHeight: Math.max(16, fallback.font.pixelSize + 2)
    width: implicitWidth
    height: implicitHeight

    readonly property var svgIcons: ({
        "activity": true,
        "archive": true,
        "arrowdown": true,
        "audio": true,
        "check": true,
        "clock": true,
        "close": true,
        "document": true,
        "download": true,
        "file": true,
        "folder": true,
        "gear": true,
        "harddrive": true,
        "image": true,
        "link": true,
        "pause": true,
        "play": true,
        "plus": true,
        "search": true,
        "trash": true,
        "video": true
    })

    function colorToken(color) {
        const normalized = Qt.rgba(color.r, color.g, color.b, color.a).toString()
        return normalized.length > 1 && normalized.charAt(0) === "#" ? normalized.slice(1) : "fffbfbfb"
    }

    function svgPathForName(name) {
        if (!svgIcons[name]) {
            return ""
        }

        return "image://dyxicon/" + name + "/" + colorToken(root.iconColor)
    }

    readonly property string svgSource: svgPathForName(iconName)
    readonly property bool wantsSvg: svgSource.length > 0

    Image {
        id: svgIcon
        anchors.fill: parent
        visible: root.wantsSvg
        source: root.svgSource
        cache: false
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        sourceSize.width: Math.max(32, Math.ceil(root.width * 2))
        sourceSize.height: Math.max(32, Math.ceil(root.height * 2))
    }

    Text {
        id: fallback
        anchors.fill: parent
        visible: !root.wantsSvg
        text: {
            if (root.iconName === "minimize") return "\u2013"
            if (root.iconName === "maximize") return "\u2195"
            return "?"
        }
        color: root.iconColor
        font.pixelSize: tokens.px(14)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }
}
