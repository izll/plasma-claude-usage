/*
    SPDX-FileCopyrightText: 2026 Hody
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// One "name | bar | percent" row for the model breakdown card.
RowLayout {
    id: row

    property string label: ""
    property real percent: 0
    property color barColor: Kirigami.Theme.positiveTextColor

    spacing: Kirigami.Units.smallSpacing
    Layout.fillWidth: true

    PlasmaComponents.Label {
        text: row.label
        Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
        elide: Text.ElideRight
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        radius: 3
        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)

        Rectangle {
            width: parent.width * Math.min(row.percent / 100, 1)
            height: parent.height
            radius: 3
            color: row.barColor
        }
    }

    PlasmaComponents.Label {
        text: Math.round(row.percent) + "%"
        font.bold: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
        horizontalAlignment: Text.AlignRight
    }
}
