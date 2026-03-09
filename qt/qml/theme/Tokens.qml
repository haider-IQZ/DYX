import QtQuick 2.15

QtObject {
    id: tokens

    readonly property Colors colors: Colors {}
    readonly property real scale: (typeof uiState !== "undefined" && uiState) ? uiState.scale : 1.0
    readonly property Typography type: Typography { scale: tokens.scale }
    readonly property Spacing spacing: Spacing { scale: tokens.scale }

    function px(value) {
        return Math.max(1, Math.round(value * scale))
    }

    readonly property int radiusSm: px(6)
    readonly property int radiusMd: px(8)
    readonly property int radiusLg: px(10)
    readonly property int radiusXl: px(14)

    readonly property int borderWidth: 1
    readonly property int titleBarHeight: px(48)
    readonly property int sidebarWidth: px(224)
    readonly property int contentHeaderHeight: px(56)
    readonly property int iconButtonSize: px(34)
    readonly property int statsIconSize: px(32)
    readonly property int cardIconSize: px(48)

    readonly property int motionFast: 120
    readonly property int motionBase: 200
    readonly property int motionSlow: 300
}
