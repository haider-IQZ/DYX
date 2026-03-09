import QtQuick 2.15
import "../theme"

Rectangle {
    id: root

    property bool hovered: false
    property bool selected: false

    color: tokens.colors.card
    border.width: tokens.borderWidth
    border.color: selected ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.5)
                           : hovered ? Qt.rgba(tokens.colors.primary.r, tokens.colors.primary.g, tokens.colors.primary.b, 0.3)
                                     : tokens.colors.border
    radius: tokens.radiusXl

    Tokens { id: tokens }

    Behavior on border.color { ColorAnimation { duration: tokens.motionBase } }
}
