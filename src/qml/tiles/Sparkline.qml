import QtQuick
import "../" as App

// Tiny inline trend chart. Draws `values` as a one-pixel antialiased
// polyline scaled to fit the component's bounds, with a small filled
// dot at the rightmost (newest) point for visual anchoring.
//
// Hidden automatically when there are fewer than 2 points — so tiles
// that place a Sparkline unconditionally still render cleanly before
// history lands.
Canvas {
    id: spark

    // --- Data ---
    property var  values: []          // array of numbers
    property bool newestFirst: true   // Ambient's history ordering

    // --- Style ---
    property color lineColor: App.Theme.accent
    property color dotColor:  lineColor
    property real  lineWidth: 1.5
    property real  dotRadius: 2.5

    // Hide until we have something to draw — keeps empty states clean.
    // Also respects the global sparklines-on/off setting.
    visible: App.AppSettings.sparklinesEnabled
             && values && values.length >= 2

    // Canvas needs a repaint request whenever any of the inputs change.
    onValuesChanged:      requestPaint()
    onLineColorChanged:   requestPaint()
    onDotColorChanged:    requestPaint()
    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!values || values.length < 2) return

        // Normalize to oldest → newest for left-to-right drawing.
        var data = newestFirst ? values.slice().reverse() : values.slice()

        // Find min/max (tolerate a flat line by widening range slightly).
        var min = Infinity, max = -Infinity
        for (var i = 0; i < data.length; i++) {
            var v = data[i]
            if (typeof v !== "number" || isNaN(v)) continue
            if (v < min) min = v
            if (v > max) max = v
        }
        if (!isFinite(min) || !isFinite(max)) return
        var range = max - min
        if (range < 0.001) range = 0.001

        // Padding keeps the stroke from clipping at the top/bottom edges
        // and leaves room on the right for the current-value dot.
        var padY = 2
        var padR = 3
        var drawH = height - padY * 2
        var drawW = width - padR - 1
        var n = data.length

        ctx.lineWidth = lineWidth
        ctx.strokeStyle = lineColor
        ctx.lineJoin = "round"
        ctx.lineCap  = "round"
        ctx.beginPath()
        for (var j = 0; j < n; j++) {
            var val = data[j]
            if (typeof val !== "number" || isNaN(val)) continue
            var x = 1 + (j / (n - 1)) * drawW
            var y = padY + drawH - ((val - min) / range) * drawH
            if (j === 0) ctx.moveTo(x, y)
            else         ctx.lineTo(x, y)
        }
        ctx.stroke()

        // Current (last) value dot.
        var lastVal = data[n - 1]
        if (typeof lastVal === "number" && !isNaN(lastVal)) {
            var lx = 1 + drawW
            var ly = padY + drawH - ((lastVal - min) / range) * drawH
            ctx.beginPath()
            ctx.fillStyle = dotColor
            ctx.arc(lx, ly, dotRadius, 0, Math.PI * 2)
            ctx.fill()
        }
    }
}
