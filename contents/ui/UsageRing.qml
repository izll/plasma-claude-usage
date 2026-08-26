/*
    SPDX-FileCopyrightText: 2026 Hody
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Anti-aliased progress ring with the percentage centered.
Item {
    id: ring

    property real percent: 0
    property real lineWidth: 4
    property color ringColor: Kirigami.Theme.positiveTextColor
    property color trackColor: Qt.alpha(Kirigami.Theme.textColor, 0.15)
    property bool showPercentSign: false
    property real fontScale: 0.3
    property real markerRel: -1   // elapsed-time fraction 0..1 shown as a dot; < 0 hides it

    readonly property real arcRadius: Math.min(width, height) / 2 - lineWidth / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Track
        ShapePath {
            strokeColor: ring.trackColor
            strokeWidth: ring.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.arcRadius
                radiusY: ring.arcRadius
                startAngle: 0
                sweepAngle: 360
            }
        }

        // Progress
        ShapePath {
            strokeColor: ring.ringColor
            strokeWidth: ring.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.arcRadius
                radiusY: ring.arcRadius
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(ring.percent, 100)) / 100
            }
        }
    }

    // Elapsed-time marker dot on the ring track
    Rectangle {
        visible: ring.markerRel >= 0
        width: Math.max(3, ring.lineWidth * 0.75)
        height: width
        radius: width / 2
        color: Kirigami.Theme.textColor
        border.color: Qt.alpha("#000000", 0.4)
        border.width: 0.5
        x: ring.width / 2 + ring.arcRadius * Math.cos(ring.markerRel * 2 * Math.PI - Math.PI / 2) - width / 2
        y: ring.height / 2 + ring.arcRadius * Math.sin(ring.markerRel * 2 * Math.PI - Math.PI / 2) - height / 2
    }

    PlasmaComponents.Label {
        anchors.centerIn: parent
        text: Math.round(ring.percent) + (ring.showPercentSign ? "%" : "")
        font.pixelSize: Math.max(8, ring.height * ring.fontScale)
        font.bold: true
    }
}
