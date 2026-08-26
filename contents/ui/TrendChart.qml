/*
    SPDX-FileCopyrightText: 2026 Hody
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

// Sparkline (line + soft area fill) of session-usage samples.
// samples: array of {t: ms-epoch, session: percent, weekly: percent}
Canvas {
    id: chart

    property var samples: []
    property color lineColor: "#D97757"

    onSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (!samples || samples.length < 2) {
            return
        }

        var pad = 2
        var t0 = samples[0].t
        var span = Math.max(samples[samples.length - 1].t - t0, 1)

        function px(s) { return pad + (width - 2 * pad) * (s.t - t0) / span }
        function py(s) { return height - pad - (height - 2 * pad) * Math.min(s.session, 100) / 100 }

        // Area fill
        ctx.beginPath()
        ctx.moveTo(px(samples[0]), height)
        for (var i = 0; i < samples.length; i++) {
            ctx.lineTo(px(samples[i]), py(samples[i]))
        }
        ctx.lineTo(px(samples[samples.length - 1]), height)
        ctx.closePath()
        ctx.fillStyle = Qt.alpha(chart.lineColor, 0.15)
        ctx.fill()

        // Line
        ctx.beginPath()
        ctx.moveTo(px(samples[0]), py(samples[0]))
        for (var j = 1; j < samples.length; j++) {
            ctx.lineTo(px(samples[j]), py(samples[j]))
        }
        ctx.strokeStyle = chart.lineColor
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.stroke()
    }
}
