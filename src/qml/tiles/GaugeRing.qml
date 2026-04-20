import QtQuick
import QtQuick.Shapes
import "../" as App

Item {
    id: gauge

    property real value: 0           // 0..1
    property color color: App.Theme.accent
    property color trackColor: App.Theme.border
    property real thickness: 10
    property real startAngle: 135    // screen angle, 0=right, 90=down, 180=left, 270=up
    property real spanAngle: 270

    readonly property real _cx: width / 2
    readonly property real _cy: height / 2
    readonly property real _r: Math.max(0, Math.min(width, height) / 2 - thickness / 2)

    function _pt(deg) {
        var a = deg * Math.PI / 180
        return Qt.point(_cx + _r * Math.cos(a), _cy + _r * Math.sin(a))
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 8

        // track
        ShapePath {
            strokeColor: gauge.trackColor
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: gauge._pt(gauge.startAngle).x
            startY: gauge._pt(gauge.startAngle).y
            PathArc {
                x: gauge._pt(gauge.startAngle + gauge.spanAngle).x
                y: gauge._pt(gauge.startAngle + gauge.spanAngle).y
                radiusX: gauge._r
                radiusY: gauge._r
                direction: PathArc.Clockwise
                useLargeArc: gauge.spanAngle > 180
            }
        }

        // value arc
        ShapePath {
            strokeColor: gauge.color
            strokeWidth: gauge.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: gauge._pt(gauge.startAngle).x
            startY: gauge._pt(gauge.startAngle).y
            PathArc {
                x: gauge._pt(gauge.startAngle + gauge.spanAngle * Math.max(0.001, Math.min(1, gauge.value))).x
                y: gauge._pt(gauge.startAngle + gauge.spanAngle * Math.max(0.001, Math.min(1, gauge.value))).y
                radiusX: gauge._r
                radiusY: gauge._r
                direction: PathArc.Clockwise
                useLargeArc: gauge.spanAngle * gauge.value > 180
            }
        }
    }

    Behavior on value { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
}
