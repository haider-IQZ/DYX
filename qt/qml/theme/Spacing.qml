import QtQuick 2.15

QtObject {
    property real scale: 1.0

    function px(value) {
        return Math.max(1, Math.round(value * scale))
    }

    readonly property int xs: px(4)
    readonly property int sm: px(8)
    readonly property int md: px(12)
    readonly property int lg: px(16)
    readonly property int xl: px(24)
    readonly property int xxl: px(32)
}
