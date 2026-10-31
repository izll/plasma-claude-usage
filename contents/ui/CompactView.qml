import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: compact

    // Cap the metrics at the panel's thickness, which the panel fixes: the
    // height in a horizontal panel, the width in a vertical one. When the
    // widget's own layout stacks its metrics along the thick axis, each one
    // gets half of it. Only the real panel orientation (formFactor) matters
    // here -- the widget's layout setting says nothing about the panel. The
    // desktop is not capped.
    readonly property bool inHorizontalPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property bool inVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int availableHeight: {
        if (inHorizontalPanel && compact.height > 0)
            return Math.max(12, root.isVerticalLayout ? Math.floor(compact.height / 2) - 2 : compact.height)
        if (inVerticalPanel && compact.width > 0)
            return Math.max(12, root.isVerticalLayout ? compact.width - 4 : Math.floor(compact.width / 2) - 2)
        return -1
    }

    function fitted(size) {
        return compact.availableHeight < 0 ? size : Math.min(size, compact.availableHeight)
    }


    // An explicitly set icon size is not scaled -- the settings page shows it
    // in pixels, so scaling it would make that label a lie -- but, like every
    // metric, it is capped at the panel thickness so it can't be clipped.
    // "Auto" means "pick something sensible", and the metrics scale is part of that.
    readonly property int effectiveIconSize: fitted(Plasmoid.configuration.iconSize > 0
        ? Plasmoid.configuration.iconSize
        : Math.round(Kirigami.Units.iconSizes.smallMedium * root.metricsScale))

    readonly property int ringSize: fitted(Math.round(28 * root.metricsScale))
    // Derived from the ring's real size, not from the scale, so a panel-capped
    // ring keeps a stroke that fits it. The stroke grows more slowly than the
    // ring: scaling it proportionally keeps the ring looking like a magnified
    // version of the small one, while a larger ring with a relatively finer
    // stroke is what reads as elegant.
    readonly property int ringLineWidth: Math.max(2, Math.round(3 + (compact.ringSize - 28) * 0.06))
    // The number inside a ring takes a slightly larger share as the widget
    // grows: at a bigger size there is room for it, and a panel-capped ring
    // would otherwise keep a number sized for a 28px ring. 100% stays at 0.3.
    readonly property real ringFontScale: Math.min(0.36, 0.3 + (root.metricsScale - 1) * 0.04)

    readonly property real ringLogoScale: Math.max(50, Math.min(Plasmoid.configuration.ringLogoSize || 85, 100)) / 100
    readonly property int barWidth: Math.round(32 * root.metricsScale)
    // In a vertical layout the widget's height comes from usageRow's implicit
    // height, so a bar sized to its parent's height would feed back into it and
    // the layout never settles (plasmashell hangs at 100% CPU, #26). Give the
    // bar its own height there; horizontally the panel fixes the row height.
    readonly property int barHeight: fitted(Math.round(Kirigami.Units.iconSizes.medium * root.metricsScale))
    // Capped against the bar's own height: a number taller than roughly half
    // the bar fills it edge to edge, and centring the font's bounding box then
    // reads as the digits sitting too high, since digits have no descenders.
    readonly property int barFontSize: compact.availableHeight < 0
        ? Math.round(9 * root.metricsScale)
        : Math.min(Math.round(9 * root.metricsScale), Math.round(compact.availableHeight * 0.5))
    readonly property int dotSize: fitted(Math.round(10 * root.metricsScale))
    // Capped so the text fits the panel thickness (text line height is ~1.4x the pixel size).
    readonly property int textFontSize: compact.availableHeight < 0
        ? Math.round(Kirigami.Theme.defaultFont.pixelSize * root.metricsScale)
        : Math.min(Math.round(Kirigami.Theme.defaultFont.pixelSize * root.metricsScale),
                   Math.max(Kirigami.Theme.defaultFont.pixelSize, Math.floor(compact.availableHeight / 1.4)))

    Layout.minimumWidth: usageRow.implicitWidth + (Plasmoid.configuration.panelMargin !== undefined ? Plasmoid.configuration.panelMargin : 4) * 2
    Layout.minimumHeight: root.isVerticalLayout ? usageRow.implicitHeight + (Plasmoid.configuration.panelMargin !== undefined ? Plasmoid.configuration.panelMargin : 4) * 2 : Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: usageRow.implicitWidth + (Plasmoid.configuration.panelMargin !== undefined ? Plasmoid.configuration.panelMargin : 4) * 2
    Layout.preferredHeight: root.isVerticalLayout ? usageRow.implicitHeight + (Plasmoid.configuration.panelMargin !== undefined ? Plasmoid.configuration.panelMargin : 4) * 2 : -1

    MouseArea {
        anchors.fill: parent
        onClicked: root.expanded = !root.expanded
    }

    GridLayout {
        id: usageRow
        anchors.centerIn: parent
        columns: root.isVerticalLayout ? 1 : -1
        rows: root.isVerticalLayout ? -1 : 1
        flow: root.isVerticalLayout ? GridLayout.TopToBottom : GridLayout.LeftToRight
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing / 2

        // Claude icon with error/update indicator
        Item {
            visible: Plasmoid.configuration.showIcon !== false
            Layout.preferredWidth: compact.effectiveIconSize
            Layout.preferredHeight: compact.effectiveIconSize
            Layout.rightMargin: Kirigami.Units.smallSpacing

            Image {
                anchors.fill: parent
                source: (Plasmoid.configuration.panelIcon || "claude") === "tile"
                    ? Qt.resolvedUrl("../icons/claude-tile.svg")
                    : Qt.resolvedUrl("../icons/claude.svg")
                sourceSize: Qt.size(parent.width * Screen.devicePixelRatio, parent.height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Rectangle {
                visible: root.hasTokenError || root.hasRateLimitError || root.hasNetworkError || root.serviceProblem || root.updateAvailable
                width: Math.max(8, Math.round(compact.effectiveIconSize / 3))
                height: width
                radius: width / 2
                color: (root.hasTokenError || root.hasRateLimitError || root.hasNetworkError || root.serviceProblem)
                    ? Kirigami.Theme.negativeTextColor
                    : "#D97757"
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -2
                anchors.bottomMargin: -2
            }
        }

        // Error state (non-token errors)
        PlasmaComponents.Label {
            visible: root.showUsageStats && root.errorMsg !== "" && !root.hasTokenError && !root.hasRateLimitError
            text: "⚠"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            color: Kirigami.Theme.negativeTextColor
        }

        // === TEXT STYLE ===

        Rectangle {
            visible: root.showUsageStats && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showSession !== false) && root.metricsVisible
            Layout.preferredWidth: compact.dotSize
            Layout.preferredHeight: compact.dotSize
            radius: compact.dotSize / 2
            color: root.getUsageColor(root.sessionUsagePercent, root.useTimeAware ? root.sessionTimePct : undefined)
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
        }

        PlasmaComponents.Label {
            visible: root.showUsageStats && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showSession !== false) && root.metricsVisible
            text: Math.round(root.sessionUsagePercent) + "%"
            font.pixelSize: compact.textFontSize
            font.bold: true
            color: root.useTimeAware ? root.getUsageColor(root.sessionUsagePercent, root.sessionTimePct) : Kirigami.Theme.textColor
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
        }

        PlasmaComponents.Label {
            visible: root.showUsageStats && !root.isVerticalLayout && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showSession !== false) && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            text: "|"
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.25 : root.isStale ? 0.35 : 0.5
            font.pixelSize: compact.textFontSize
        }

        Rectangle {
            visible: root.showUsageStats && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: compact.dotSize
            Layout.preferredHeight: compact.dotSize
            radius: compact.dotSize / 2
            color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
        }

        PlasmaComponents.Label {
            visible: root.showUsageStats && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            text: Math.round(root.weeklyUsagePercent) + "%"
            font.pixelSize: compact.textFontSize
            font.bold: true
            color: root.useTimeAware ? root.getUsageColor(root.weeklyUsagePercent, root.weeklyTimePct) : Kirigami.Theme.textColor
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
        }

        Repeater {
            model: root.modelLimits
            delegate: Row {
                visible: root.showUsageStats && root.effectivePanelStyle === "text" && root.isModelShownInPanel(modelData.label) && root.metricsVisible
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    visible: !root.isVerticalLayout && ((Plasmoid.configuration.showSession !== false) || (Plasmoid.configuration.showWeekly !== false))
                    text: "|"
                    opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.25 : root.isStale ? 0.35 : 0.5
                    font.pixelSize: compact.textFontSize
                }

                Rectangle {
                    width: compact.dotSize; height: compact.dotSize; radius: compact.dotSize / 2
                    color: root.getUsageColor(modelData.percent, root.useTimeAware ? root.weeklyTimePct : undefined)
                    opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
                    anchors.verticalCenter: parent.verticalCenter
                }

                PlasmaComponents.Label {
                    text: Math.round(modelData.percent) + "%"
                    font.pixelSize: compact.textFontSize
                    font.bold: true
                    color: root.useTimeAware ? root.getUsageColor(modelData.percent, root.weeklyTimePct) : Kirigami.Theme.textColor
                    opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
                }
            }
        }

        // === BAR STYLE ===

        Item {
            visible: root.showUsageStats && root.effectivePanelStyle === "bar" && (Plasmoid.configuration.showSession !== false) && root.metricsVisible
            Layout.preferredWidth: compact.barWidth
            Layout.preferredHeight: root.isVerticalLayout ? compact.barHeight : parent.height
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: Math.max((parent.height - 2) * Math.min(root.sessionUsagePercent / 100, 1), 1)
                    radius: 2
                    color: root.getUsageColor(root.sessionUsagePercent, root.useTimeAware ? root.sessionTimePct : undefined)
                }

                Rectangle {
                    visible: root.useTimeAware && root.sessionTimePct >= 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    y: parent.height - 1 - (parent.height - 2) * Math.min(Math.max(root.sessionTimePct, 0), 100) / 100
                    height: 2
                    color: Kirigami.Theme.textColor
                    opacity: 0.6
                }
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: Math.round(root.sessionUsagePercent)
                font.pixelSize: compact.barFontSize
                font.bold: true
                color: Kirigami.Theme.textColor
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }

        Item {
            visible: root.showUsageStats && root.effectivePanelStyle === "bar" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: compact.barWidth
            Layout.preferredHeight: root.isVerticalLayout ? compact.barHeight : parent.height
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: Math.max((parent.height - 2) * Math.min(root.weeklyUsagePercent / 100, 1), 1)
                    radius: 2
                    color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
                }

                Rectangle {
                    visible: root.useTimeAware && root.weeklyTimePct >= 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    y: parent.height - 1 - (parent.height - 2) * Math.min(Math.max(root.weeklyTimePct, 0), 100) / 100
                    height: 2
                    color: Kirigami.Theme.textColor
                    opacity: 0.6
                }
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: Math.round(root.weeklyUsagePercent)
                font.pixelSize: compact.barFontSize
                font.bold: true
                color: Kirigami.Theme.textColor
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }

        Repeater {
            model: root.modelLimits
            delegate: Item {
                visible: root.showUsageStats && root.effectivePanelStyle === "bar" && root.isModelShownInPanel(modelData.label) && root.metricsVisible
                Layout.preferredWidth: compact.barWidth
                Layout.preferredHeight: root.isVerticalLayout ? compact.barHeight : parent.height
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    border.width: 1

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 1
                        height: Math.max((parent.height - 2) * Math.min(modelData.percent / 100, 1), 1)
                        radius: 2
                        color: root.getUsageColor(modelData.percent, root.useTimeAware ? root.weeklyTimePct : undefined)
                    }

                    Rectangle {
                        visible: root.useTimeAware && root.weeklyTimePct >= 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 1
                        y: parent.height - 1 - (parent.height - 2) * Math.min(Math.max(root.weeklyTimePct, 0), 100) / 100
                        height: 2
                        color: Kirigami.Theme.textColor
                        opacity: 0.6
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: Math.round(modelData.percent)
                    font.pixelSize: compact.barFontSize
                    font.bold: true
                    color: Kirigami.Theme.textColor
                    style: Text.Outline
                    styleColor: Kirigami.Theme.backgroundColor
                }
            }
        }

        // === RING STYLE ===

        UsageRing {
            visible: root.showUsageStats && root.effectivePanelStyle === "ring" && (Plasmoid.configuration.showSession !== false) && root.metricsVisible
            Layout.preferredWidth: compact.ringSize
            Layout.preferredHeight: compact.ringSize
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            percent: root.sessionUsagePercent
            ringColor: root.getUsageColor(root.sessionUsagePercent, root.useTimeAware ? root.sessionTimePct : undefined)
            markerRel: root.useTimeAware && root.sessionTimePct >= 0 ? root.sessionTimePct / 100 : -1
            lineWidth: compact.ringLineWidth
            fontScale: compact.ringFontScale
            centerIcon: (Plasmoid.configuration.ringCenter || "percent").indexOf("logo") === 0
                ? Qt.resolvedUrl((Plasmoid.configuration.panelIcon || "claude") === "tile"
                ? "../icons/claude-tile.svg" : "../icons/claude.svg").toString()
                : ""
            centerPercentOverlay: (Plasmoid.configuration.ringCenter || "percent") === "logo_percent"
            logoScale: compact.ringLogoScale
            cornerLabel: Plasmoid.configuration.showWindowLabels === true ? "5h" : ""
        }

        UsageRing {
            visible: root.showUsageStats && root.effectivePanelStyle === "ring" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: compact.ringSize
            Layout.preferredHeight: compact.ringSize
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            percent: root.weeklyUsagePercent
            ringColor: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
            markerRel: root.useTimeAware && root.weeklyTimePct >= 0 ? root.weeklyTimePct / 100 : -1
            lineWidth: compact.ringLineWidth
            fontScale: compact.ringFontScale
            centerIcon: (Plasmoid.configuration.ringCenter || "percent").indexOf("logo") === 0
                ? Qt.resolvedUrl((Plasmoid.configuration.panelIcon || "claude") === "tile"
                ? "../icons/claude-tile.svg" : "../icons/claude.svg").toString()
                : ""
            centerPercentOverlay: (Plasmoid.configuration.ringCenter || "percent") === "logo_percent"
            logoScale: compact.ringLogoScale
            cornerLabel: Plasmoid.configuration.showWindowLabels === true ? "7d" : ""
        }

        Repeater {
            model: root.modelLimits
            delegate: UsageRing {
                visible: root.showUsageStats && root.effectivePanelStyle === "ring" && root.isModelShownInPanel(modelData.label) && root.metricsVisible
                Layout.preferredWidth: compact.ringSize
                Layout.preferredHeight: compact.ringSize
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
                percent: modelData.percent
                ringColor: root.getUsageColor(modelData.percent, root.useTimeAware ? root.weeklyTimePct : undefined)
                markerRel: root.useTimeAware && root.weeklyTimePct >= 0 ? root.weeklyTimePct / 100 : -1
                lineWidth: compact.ringLineWidth
                fontScale: compact.ringFontScale
                centerIcon: (Plasmoid.configuration.ringCenter || "percent").indexOf("logo") === 0
                    ? Qt.resolvedUrl((Plasmoid.configuration.panelIcon || "claude") === "tile"
                    ? "../icons/claude-tile.svg" : "../icons/claude.svg").toString()
                    : ""
                centerPercentOverlay: (Plasmoid.configuration.ringCenter || "percent") === "logo_percent"
                logoScale: compact.ringLogoScale
            }
        }

        // Error text (non-token errors only)
        PlasmaComponents.Label {
            visible: root.showUsageStats && root.errorMsg !== "" && !root.hasTokenError && !root.hasRateLimitError
            text: root.errorMsg
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: Kirigami.Theme.negativeTextColor
        }
    }
}
