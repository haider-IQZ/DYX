import QtQuick 2.15
import "../theme"

Rectangle {
    id: root

    property bool hovered: false
    property bool selected: false

    color: tokens.colors.card
    border.width: 0
    border.color: "transparent"
    radius: tokens.radiusXl

    Tokens { id: tokens }
}
