import QtQuick 2.15

QtObject {
    readonly property Colors colors: Colors {}
    readonly property Typography type: Typography {}
    readonly property Spacing spacing: Spacing {}

    readonly property int radiusSm: 6
    readonly property int radiusMd: 8
    readonly property int radiusLg: 10
    readonly property int radiusXl: 14

    readonly property int borderWidth: 1
    readonly property int titleBarHeight: 48
    readonly property int sidebarWidth: 224
    readonly property int contentHeaderHeight: 56
    readonly property int iconButtonSize: 34
    readonly property int statsIconSize: 32
    readonly property int cardIconSize: 48

    readonly property int motionFast: 120
    readonly property int motionBase: 200
    readonly property int motionSlow: 300
}
