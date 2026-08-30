import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: compact

    readonly property int effectiveIconSize: Plasmoid.configuration.iconSize > 0 ? Plasmoid.configuration.iconSize : Kirigami.Units.iconSizes.smallMedium

    Layout.minimumWidth: usageRow.implicitWidth + Kirigami.Units.largeSpacing * 2
    Layout.minimumHeight: root.isVerticalLayout ? usageRow.implicitHeight + Kirigami.Units.largeSpacing * 2 : Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: usageRow.implicitWidth + Kirigami.Units.largeSpacing * 2
    Layout.preferredHeight: root.isVerticalLayout ? usageRow.implicitHeight + Kirigami.Units.largeSpacing * 2 : -1

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
                visible: root.hasTokenError || root.hasRateLimitError || root.hasNetworkError || root.updateAvailable
                width: 8
                height: 8
                radius: 4
                color: (root.hasTokenError || root.hasRateLimitError || root.hasNetworkError)
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
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: root.getUsageColor(root.sessionUsagePercent, root.useTimeAware ? root.sessionTimePct : undefined)
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
        }

        PlasmaComponents.Label {
            visible: root.showUsageStats && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showSession !== false) && root.metricsVisible
            text: Math.round(root.sessionUsagePercent) + "%"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            font.bold: true
            color: root.useTimeAware ? root.getUsageColor(root.sessionUsagePercent, root.sessionTimePct) : Kirigami.Theme.textColor
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
        }

        PlasmaComponents.Label {
            visible: root.showUsageStats && !root.isVerticalLayout && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showSession !== false) && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            text: "|"
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.25 : root.isStale ? 0.35 : 0.5
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
        }

        Rectangle {
            visible: root.showUsageStats && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
        }

        PlasmaComponents.Label {
            visible: root.showUsageStats && root.effectivePanelStyle === "text" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            text: Math.round(root.weeklyUsagePercent) + "%"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
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
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                }

                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: root.getUsageColor(modelData.percent, root.useTimeAware ? root.weeklyTimePct : undefined)
                    opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
                    anchors.verticalCenter: parent.verticalCenter
                }

                PlasmaComponents.Label {
                    text: Math.round(modelData.percent) + "%"
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    font.bold: true
                    color: root.useTimeAware ? root.getUsageColor(modelData.percent, root.weeklyTimePct) : Kirigami.Theme.textColor
                    opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
                }
            }
        }

        // === BAR STYLE ===

        Item {
            visible: root.showUsageStats && root.effectivePanelStyle === "bar" && (Plasmoid.configuration.showSession !== false) && root.metricsVisible
            Layout.preferredWidth: 32
            Layout.preferredHeight: parent.height
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
                font.pixelSize: 9
                font.bold: true
                color: Kirigami.Theme.textColor
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }

        Item {
            visible: root.showUsageStats && root.effectivePanelStyle === "bar" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: 32
            Layout.preferredHeight: parent.height
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
                font.pixelSize: 9
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
                Layout.preferredWidth: 32
                Layout.preferredHeight: parent.height
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
                    font.pixelSize: 9
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
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            percent: root.sessionUsagePercent
            ringColor: root.getUsageColor(root.sessionUsagePercent, root.useTimeAware ? root.sessionTimePct : undefined)
            markerRel: root.useTimeAware && root.sessionTimePct >= 0 ? root.sessionTimePct / 100 : -1
            lineWidth: 3
            fontScale: 0.3
        }

        UsageRing {
            visible: root.showUsageStats && root.effectivePanelStyle === "ring" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            percent: root.weeklyUsagePercent
            ringColor: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
            markerRel: root.useTimeAware && root.weeklyTimePct >= 0 ? root.weeklyTimePct / 100 : -1
            lineWidth: 3
            fontScale: 0.3
        }

        Repeater {
            model: root.modelLimits
            delegate: UsageRing {
                visible: root.showUsageStats && root.effectivePanelStyle === "ring" && root.isModelShownInPanel(modelData.label) && root.metricsVisible
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
                percent: modelData.percent
                ringColor: root.getUsageColor(modelData.percent, root.useTimeAware ? root.weeklyTimePct : undefined)
                markerRel: root.useTimeAware && root.weeklyTimePct >= 0 ? root.weeklyTimePct / 100 : -1
                lineWidth: 3
                fontScale: 0.3
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
