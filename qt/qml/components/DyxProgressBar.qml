import QtQuick 2.15
import "../theme"

Item {
    id: root

    property real value: 0
    property color fillColor: tokens.colors.primary
    property color trackColor: tokens.colors.muted

    implicitHeight: 6
    implicitWidth: 240

    Tokens { id: tokens }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0, Math.min(parent.width, parent.width * Math.max(0, Math.min(1, root.value))))
        radius: height / 2
        color: root.fillColor

        Behavior on width {
            NumberAnimation { duration: tokens.motionBase; easing.type: Easing.OutCubic }
        }
    }
}
