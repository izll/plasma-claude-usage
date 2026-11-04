/*
    SPDX-FileCopyrightText: 2026 noctuum
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// A status.claude.com problem with Claude Code or the API, drawn like the
// error cards of the popup style it sits in. Clicking it opens the status page.
Rectangle {
    id: card

    property bool classic: false
    readonly property color tone: root.serviceOutage
        ? Kirigami.Theme.negativeTextColor
        : Kirigami.Theme.neutralTextColor
    readonly property int padding: card.classic ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing

    visible: root.serviceProblem
    Layout.fillWidth: true
    Layout.bottomMargin: card.classic ? Kirigami.Units.smallSpacing : 0
    implicitHeight: content.implicitHeight + card.padding * 2
    radius: card.classic ? 5 : Kirigami.Units.cornerRadius
    color: card.classic
        ? (root.serviceOutage ? Kirigami.Theme.negativeBackgroundColor : Kirigami.Theme.neutralBackgroundColor)
        : Qt.alpha(card.tone, cardMouse.containsMouse ? 0.2 : 0.12)

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.serviceIssues

                    PlasmaComponents.Label {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "⚠ " + modelData.name + ": " + root.serviceStatusText(modelData.status)
                        textFormat: Text.PlainText
                        color: card.tone
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignTop
                text: "↗"
                color: card.tone
                opacity: cardMouse.containsMouse ? 1 : 0.6
            }
        }

        PlasmaComponents.Label {
            visible: root.serviceIncident !== ""
            Layout.fillWidth: true
            text: root.serviceIncident
            textFormat: Text.PlainText
            color: card.tone
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Qt.openUrlExternally("https://status.claude.com")
    }
}
