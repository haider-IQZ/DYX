import QtQuick 2.15
import QtQuick.Controls 2.15
import "../theme"

Popup {
    id: root

    default property alias dialogContent: contentColumn.data
    property int dialogWidth: 520
    property var hostWindow: null
    parent: hostWindow && hostWindow.overlay ? hostWindow.overlay : Overlay.overlay
    width: dialogWidth
    height: contentItem ? contentItem.implicitHeight : 0
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape
    x: Math.round((((parent && parent.width) ? parent.width : 0) - width) / 2)
    y: Math.round((((parent && parent.height) ? parent.height : 0) - height) / 2)

    Overlay.modal: Rectangle {
        color: "#99000000"
    }

    background: Rectangle {
        radius: tokens.radiusXl
        color: tokens.colors.card
        border.width: 1
        border.color: tokens.colors.border
    }

    contentItem: Column {
        id: contentColumn
        width: root.dialogWidth
    }

    Tokens { id: tokens }
}
