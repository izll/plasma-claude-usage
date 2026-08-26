/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-FileCopyrightText: 2026 Hody
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: full
    clip: true

    readonly property color accent: "#D97757"
    readonly property color cardColor: Qt.alpha(Kirigami.Theme.textColor, 0.07)

    property double footerNow: Date.now()
    property bool editMode: false
    property int dragFromIndex: -1
    property int dragOverIndex: -1

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton && !full.editMode)
                contextMenu.popup()
        }
    }

    PlasmaComponents.Menu {
        id: contextMenu
        PlasmaComponents.MenuItem {
            text: i18n.tr("Edit cards")
            icon.name: "configure"
            onClicked: full.editMode = true
        }
    }

    Timer {
        interval: 1000
        running: full.visible
        repeat: true
        onTriggered: full.footerNow = Date.now()
    }

    readonly property string statusText: {
        if (root.lastSuccessTime <= 0) return i18n.tr("Loading...")
        var ago = Math.max(0, Math.floor((full.footerNow - root.lastSuccessTime) / 1000))
        var duration
        if (ago < 60) duration = ago + "s"
        else if (ago < 3600) duration = Math.floor(ago / 60) + "m"
        else duration = Math.floor(ago / 3600) + "h " + Math.floor((ago % 3600) / 60) + "m"
        var text = i18n.tr("Updated {duration} ago").replace("{duration}", duration)
        var nextPoll = root.lastFetchTime + Math.max(Plasmoid.configuration.refreshInterval || 5, 1) * 60000
        if (ago >= 60 && nextPoll > full.footerNow && !root.hasRateLimitError) {
            var untilMin = Math.ceil((nextPoll - full.footerNow) / 60000)
            text += " · " + i18n.tr("Next update in {duration}").replace("{duration}", untilMin + "m")
        }
        return text
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 19
    Layout.preferredWidth: Kirigami.Units.gridUnit * 21
    Layout.minimumHeight: mainColumn.implicitHeight + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: mainColumn.implicitHeight + Kirigami.Units.smallSpacing * 2

    property var cardOrder: []

    readonly property var cardNames: ({
        "account": "Account",
        "usage": "Session & Weekly",
        "models": "By Model (Weekly)",
        "extra": "Extra Usage",
        "tokens": "Today's Tokens",
        "trend": "7-day trend",
        "installations": "Claude Code",
        "links": "Quick links"
    })

    function parseCardOrder() {
        try {
            cardOrder = JSON.parse(Plasmoid.configuration.cardOrder || "[]")
        } catch (e) {
            cardOrder = []
        }
        if (cardOrder.length === 0) {
            cardOrder = [
                {id: "account", enabled: true},
                {id: "usage", enabled: true},
                {id: "models", enabled: true},
                {id: "extra", enabled: true},
                {id: "tokens", enabled: true},
                {id: "trend", enabled: true},
                {id: "installations", enabled: true},
                {id: "links", enabled: true}
            ]
        }
    }

    Component.onCompleted: parseCardOrder()
    Connections {
        target: Plasmoid.configuration
        function onCardOrderChanged() { full.parseCardOrder() }
    }

    function moveCard(fromIdx, toIdx) {
        if (fromIdx < 0 || toIdx < 0 || fromIdx >= cardOrder.length || toIdx >= cardOrder.length || fromIdx === toIdx) return
        var list = cardOrder.slice()
        var item = list.splice(fromIdx, 1)[0]
        list.splice(toIdx, 0, item)
        cardOrder = list
        Plasmoid.configuration.cardOrder = JSON.stringify(list)
    }

    function toggleCard(idx) {
        if (idx < 0 || idx >= cardOrder.length) return
        var list = cardOrder.slice()
        list[idx] = {id: list[idx].id, enabled: !list[idx].enabled}
        cardOrder = list
        Plasmoid.configuration.cardOrder = JSON.stringify(list)
    }

    property var cardComponents: ({
        "account": cardAccountComp,
        "usage": cardUsageComp,
        "models": cardModelsComp,
        "extra": cardExtraComp,
        "tokens": cardTokensComp,
        "trend": cardTrendComp,
        "installations": cardInstallationsComp,
        "links": cardLinksComp
    })

    // ===== Card Component definitions =====

    Component {
        id: cardAccountComp
        Rectangle {
            visible: root.accountEmail !== "" || root.planName !== ""
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? accountInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: accountInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                    text: i18n.tr("Account")
                }

                RowLayout {
                    visible: root.accountEmail !== ""
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: i18n.tr("Email"); opacity: 0.65 }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.accountEmail
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    visible: root.planName !== ""
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: i18n.tr("Plan"); opacity: 0.65 }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.planName
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    Component {
        id: cardUsageComp
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.mediumSpacing

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Kirigami.Units.cornerRadius
                color: full.cardColor
                implicitHeight: sessionCol.implicitHeight + Kirigami.Units.mediumSpacing * 2

                ColumnLayout {
                    id: sessionCol
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.mediumSpacing
                    spacing: Kirigami.Units.smallSpacing

                    UsageRing {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 56; Layout.preferredHeight: 56
                        percent: root.sessionUsagePercent
                        ringColor: root.getUsageColor(root.sessionUsagePercent, root.useTimeAware ? root.sessionTimePct : undefined)
                        markerRel: root.useTimeAware && root.sessionTimePct >= 0 ? root.sessionTimePct / 100 : -1
                        lineWidth: 5; showPercentSign: true; fontScale: 0.22
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: i18n.tr("Session (5hr)")
                        font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.sessionResetTime !== null && root.formatTimeRemaining(root.sessionResetTime) !== ""
                        text: i18n.tr("resets in") + " " + root.formatTimeRemaining(root.sessionResetTime)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.65; elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Kirigami.Units.cornerRadius
                color: full.cardColor
                implicitHeight: weeklyCol.implicitHeight + Kirigami.Units.mediumSpacing * 2

                ColumnLayout {
                    id: weeklyCol
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.mediumSpacing
                    spacing: Kirigami.Units.smallSpacing

                    UsageRing {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 56; Layout.preferredHeight: 56
                        percent: root.weeklyUsagePercent
                        ringColor: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
                        markerRel: root.useTimeAware && root.weeklyTimePct >= 0 ? root.weeklyTimePct / 100 : -1
                        lineWidth: 5; showPercentSign: true; fontScale: 0.22
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: i18n.tr("Weekly (7day)")
                        font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.weeklyResetTime !== null && root.formatTimeRemaining(root.weeklyResetTime) !== ""
                        text: i18n.tr("resets in") + " " + root.formatTimeRemaining(root.weeklyResetTime)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.65; elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Component {
        id: cardModelsComp
        Rectangle {
            visible: root.modelUsage.length > 0 || root.modelLimits.length > 0
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? modelInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: modelInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1; font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                    text: i18n.tr("By Model (Weekly)")
                }

                Repeater {
                    model: root.modelUsage.length > 0 ? root.modelUsage : root.modelLimits
                    delegate: ModelRow {
                        required property var modelData
                        label: root.modelUsage.length > 0 ? modelData.name : modelData.label
                        percent: modelData.percent
                        barColor: (root.modelUsage.length > 0 && modelData.key === "fable")
                            ? "#D97757" : root.getUsageColor(modelData.percent, root.useTimeAware ? root.weeklyTimePct : undefined)
                    }
                }

                PlasmaComponents.Label {
                    visible: root.modelUsage.length > 0
                    text: i18n.tr("Other models aren't reported by the API yet")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                    font.italic: true; opacity: 0.45
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
            }
        }
    }

    Component {
        id: cardExtraComp
        Rectangle {
            visible: root.extraEnabled
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? extraInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: extraInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1; font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                    text: i18n.tr("Extra Usage")
                }
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: root.formatDollars(root.extraUsedCents) + " / " + root.formatDollars(root.extraLimitCents) + " " + i18n.tr("spent") }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label { text: Math.round(root.extraPercent) + "%"; font.bold: true; color: root.getUsageColor(root.extraPercent) }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                    Rectangle {
                        width: parent.width * Math.min(root.extraPercent / 100, 1); height: parent.height; radius: 3
                        color: root.getUsageColor(root.extraPercent)
                    }
                }
            }
        }
    }

    Component {
        id: cardTokensComp
        Rectangle {
            visible: root.tokenStats.length > 0
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? tokensInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: tokensInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1; font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                        text: i18n.tr("Today's Tokens")
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label { text: i18n.tr("local logs"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.55 }
                }

                Repeater {
                    model: root.tokenStats
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing
                        PlasmaComponents.Label { text: modelData.name; Layout.preferredWidth: Kirigami.Units.gridUnit * 4; elide: Text.ElideRight }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Label { text: root.formatTokens(modelData.output) + " " + i18n.tr("out"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.55 }
                        PlasmaComponents.Label { text: root.formatTokens(modelData.total); font.bold: true; Layout.preferredWidth: Kirigami.Units.gridUnit * 3; horizontalAlignment: Text.AlignRight }
                    }
                }
            }
        }
    }

    Component {
        id: cardTrendComp
        Rectangle {
            visible: root.usageSamples.length >= 2
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? trendInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: trendInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1; font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                        text: i18n.tr("7-day trend")
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label { text: i18n.tr("session usage"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.55 }
                }

                TrendChart {
                    Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                    samples: root.usageSamples; lineColor: full.accent
                }
            }
        }
    }

    Component {
        id: cardInstallationsComp
        Rectangle {
            visible: root.installations.length > 0
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? installInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: installInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1; font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                    text: "Claude Code"
                }
                Repeater {
                    model: root.installations
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        PlasmaComponents.Label { text: modelData.name; opacity: 0.65 }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Label { text: modelData.version }
                    }
                }
            }
        }
    }

    Component {
        id: cardLinksComp
        Rectangle {
            visible: root.parsedQuickLinks.length > 0
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? linksFlow.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            RowLayout {
                id: linksFlow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing
                Item { Layout.fillWidth: true }

                Repeater {
                    model: root.parsedQuickLinks
                    delegate: Rectangle {
                        radius: Kirigami.Units.cornerRadius
                        color: linkMa.containsMouse
                            ? Qt.alpha(Kirigami.Theme.textColor, 0.15)
                            : Qt.alpha(Kirigami.Theme.textColor, 0.08)
                        implicitWidth: linkRow.implicitWidth + Kirigami.Units.mediumSpacing * 2
                        implicitHeight: linkRow.implicitHeight + Kirigami.Units.smallSpacing * 2

                        RowLayout {
                            id: linkRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                source: modelData.icon || "internet-web-browser"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }
                            PlasmaComponents.Label {
                                text: modelData.name
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }
                        }
                        MouseArea {
                            id: linkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(modelData.url)
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    // ===== Main layout =====

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        anchors.leftMargin: Kirigami.Units.mediumSpacing
        anchors.rightMargin: Kirigami.Units.mediumSpacing
        spacing: Kirigami.Units.smallSpacing

        // ===== Header (always shown) =====
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: (Plasmoid.configuration.panelIcon || "claude") === "tile"
                    ? Qt.resolvedUrl("../icons/claude-tile.svg")
                    : Qt.resolvedUrl("../icons/claude.svg")
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            PlasmaComponents.Label {
                text: i18n.tr("Claude Usage")
                font.bold: true
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.25
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.ToolButton {
                visible: full.editMode
                icon.name: "dialog-ok-apply"
                onClicked: full.editMode = false
                PlasmaComponents.ToolTip { text: i18n.tr("Done") }
            }

            Rectangle {
                visible: root.planName !== ""
                Layout.preferredWidth: planLabel.implicitWidth + Kirigami.Units.largeSpacing
                Layout.preferredHeight: planLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: height / 2
                color: Qt.alpha(full.accent, 0.18)

                PlasmaComponents.Label {
                    id: planLabel
                    anchors.centerIn: parent
                    text: root.planName
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true; color: full.accent
                }
            }
        }

        // ===== Error cards =====
        Rectangle {
            visible: !full.editMode && root.errorMsg !== "" && !root.hasTokenError && !root.hasRateLimitError
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.12)
            implicitHeight: errorColumn.implicitHeight + Kirigami.Units.largeSpacing * 2

            ColumnLayout {
                id: errorColumn
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: "⚠ " + root.errorMsg
                    color: Kirigami.Theme.negativeTextColor
                    font.bold: true
                }
                PlasmaComponents.Label {
                    text: root.baseUrl
                        ? i18n.tr("Check base URL and API key in widget settings")
                        : i18n.tr("Run 'claude' to log in")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.negativeTextColor
                }
            }
        }

        Rectangle {
            visible: !full.editMode && root.hasTokenError
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.12)
            implicitHeight: tokenErrorColumn.implicitHeight + Kirigami.Units.largeSpacing * 2

            ColumnLayout {
                id: tokenErrorColumn
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: "⚠ " + i18n.tr("Re-login required")
                    color: Kirigami.Theme.negativeTextColor
                    font.bold: true
                }

                PlasmaComponents.Button {
                    text: i18n.tr("Open Claude")
                    icon.name: "utilities-terminal"
                    onClicked: root.launchInTerminal("claude")
                }
            }
        }

        Rectangle {
            visible: !full.editMode && root.hasRateLimitError
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.12)
            implicitHeight: rateLimitColumn.implicitHeight + Kirigami.Units.largeSpacing * 2

            ColumnLayout {
                id: rateLimitColumn
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: "⚠ " + i18n.tr("Rate limited")
                    color: Kirigami.Theme.negativeTextColor
                    font.bold: true
                }
                PlasmaComponents.Label {
                    text: i18n.tr("Auto-retry in") + " " + Math.round(root.rateLimitBackoffMs / 60000) + " min"
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.negativeTextColor
                }
            }
        }

        // ===== Dynamic cards from cardOrder =====
        Repeater {
            id: cardsRepeater
            model: full.cardOrder

            Item {
                id: cardWrapper
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: innerColumn.implicitHeight
                visible: full.editMode
                    || (modelData.enabled !== false
                        && (!cardContent.item || cardContent.item.visible))

                DropArea {
                    anchors.fill: parent
                    enabled: full.editMode
                    onEntered: full.dragOverIndex = cardWrapper.index
                }

                ColumnLayout {
                    id: innerColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    // Edit mode bar
                    RowLayout {
                        id: editBar
                        visible: full.editMode
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "handle-sort"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            opacity: 0.5

                            MouseArea {
                                id: dragHandle
                                anchors.fill: parent
                                anchors.margins: -Kirigami.Units.smallSpacing
                                cursorShape: Qt.SizeAllCursor
                                drag.target: dragProxy
                                drag.axis: Drag.YAxis

                                onPressed: function(mouse) {
                                    full.dragFromIndex = cardWrapper.index
                                    var pos = dragHandle.mapToItem(full, 0, 0)
                                    dragProxy.x = pos.x
                                    dragProxy.y = pos.y
                                    dragProxy.cardId = cardWrapper.modelData.id
                                    dragProxy.visible = true
                                    dragProxy.Drag.active = true
                                }
                                onReleased: {
                                    dragProxy.Drag.drop()
                                    dragProxy.visible = false
                                    dragProxy.Drag.active = false
                                    if (full.dragFromIndex >= 0 && full.dragOverIndex >= 0 && full.dragFromIndex !== full.dragOverIndex) {
                                        full.moveCard(full.dragFromIndex, full.dragOverIndex)
                                    }
                                    full.dragFromIndex = -1
                                    full.dragOverIndex = -1
                                }
                            }
                        }

                        PlasmaComponents.CheckBox {
                            checked: cardWrapper.modelData.enabled !== false
                            onToggled: full.toggleCard(cardWrapper.index)
                        }

                        PlasmaComponents.Label {
                            text: i18n.tr(full.cardNames[cardWrapper.modelData.id] || cardWrapper.modelData.id)
                            Layout.fillWidth: true
                            opacity: cardWrapper.modelData.enabled !== false ? 1.0 : 0.45
                        }

                        PlasmaComponents.ToolButton {
                            icon.name: "go-up"
                            enabled: cardWrapper.index > 0
                            visible: full.editMode
                            onClicked: full.moveCard(cardWrapper.index, cardWrapper.index - 1)
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                            Layout.preferredHeight: Layout.preferredWidth
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: "go-down"
                            enabled: cardWrapper.index < full.cardOrder.length - 1
                            visible: full.editMode
                            onClicked: full.moveCard(cardWrapper.index, cardWrapper.index + 1)
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                            Layout.preferredHeight: Layout.preferredWidth
                        }

                    }

                    // Card content
                    Loader {
                        id: cardContent
                        active: cardWrapper.modelData.enabled !== false
                        Layout.fillWidth: true
                        sourceComponent: full.cardComponents[cardWrapper.modelData.id] || null
                        opacity: full.editMode ? 0.35 : 1.0
                    }
                }
            }
        }

        // Refresh-interval warning
        PlasmaComponents.Label {
            visible: !full.editMode && (Plasmoid.configuration.refreshInterval || 5) < 5
            text: "⚠ " + i18n.tr("Values under 5 min may cause rate limiting")
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: Kirigami.Theme.neutralTextColor
            font.italic: true
            Layout.fillWidth: true; wrapMode: Text.WordWrap
        }

        // ===== Footer =====
        RowLayout {
            visible: !full.editMode
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                visible: root.updateAvailable
                Layout.preferredWidth: updateLabel.implicitWidth + Kirigami.Units.largeSpacing
                Layout.preferredHeight: updateLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: height / 2
                color: Qt.alpha(full.accent, 0.18)

                PlasmaComponents.Label {
                    id: updateLabel
                    anchors.centerIn: parent
                    text: "⬆ " + root.latestVersion + " " + i18n.tr("available")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true; color: full.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchInTerminal("claude update")
                }
            }

            PlasmaComponents.Label {
                text: full.statusText
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                opacity: 0.65; elide: Text.ElideRight
                Layout.fillWidth: false
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                text: i18n.tr("Refresh")
                onClicked: root.refresh()
            }
        }
    }

    // Drag proxy
    Rectangle {
        id: dragProxy
        visible: false
        width: mainColumn.width
        height: Kirigami.Units.gridUnit * 1.5
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(full.accent, 0.15)
        border.color: full.accent
        border.width: 1
        z: 100

        property string cardId: ""

        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        PlasmaComponents.Label {
            anchors.centerIn: parent
            text: i18n.tr(full.cardNames[dragProxy.cardId] || dragProxy.cardId)
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: full.accent
            font.bold: true
        }
    }
}
