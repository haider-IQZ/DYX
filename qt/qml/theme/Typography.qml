import QtQuick 2.15

QtObject {
    property real scale: 1.0

    function px(value) {
        return Math.max(1, Math.round(value * scale))
    }

    readonly property string sans: "SF Pro Display"
    readonly property string mono: "SF Mono"
    readonly property int titleBarTitle: px(14)
    readonly property int titleBarSubtitle: px(12)
    readonly property int sectionLabel: px(11)
    readonly property int sectionHeading: px(18)
    readonly property int body: px(14)
    readonly property int bodySmall: px(13)
    readonly property int caption: px(12)
    readonly property int micro: px(11)
    readonly property int statValue: px(24)
    readonly property int button: px(14)
}
