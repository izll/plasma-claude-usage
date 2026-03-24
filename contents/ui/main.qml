import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // Translations
    Translations {
        id: i18n
        currentLanguage: Plasmoid.configuration.language || "system"
    }

    property real sessionUsagePercent: 0
    property real weeklyUsagePercent: 0
    property real sonnetWeeklyPercent: 0
    property real opusWeeklyPercent: 0
    property string lastUpdate: ""
    property string planName: ""
    property string sessionReset: ""
    property string weeklyReset: ""
    property string errorMsg: ""
    property string accessToken: ""
    property string apiKey: ""
    property string baseUrl: ""
    property bool isLoading: false
    property var sessionResetTime: null
    property var weeklyResetTime: null
    property bool hasSonnetData: false
    property bool hasOpusData: false
    property bool hasTokenError: false
    property bool hasRateLimitError: false

    // Data source for reading credentials file
    Plasma5Support.DataSource {
        id: fileReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = data["stdout"] || ""
            disconnectSource(sourceName)

            console.log("Claude Usage: Got credentials, length:", stdout.length)

            if (stdout.length > 10) {
                try {
                    var creds = JSON.parse(stdout)
                    var oauth = creds.claudeAiOauth || {}
                    root.accessToken = oauth.accessToken || ""

                    // Get plan name from tier
                    var tier = oauth.rateLimitTier || "default_claude_pro"
                    var planMap = {
                        "default_claude_pro": "Pro",
                        "default_claude_max_5x": "Max 5x",
                        "default_claude_max_20x": "Max 20x"
                    }
                    root.planName = planMap[tier] || tier

                    console.log("Claude Usage: Token found, plan:", root.planName)

                    if (root.accessToken) {
                        fetchUsageFromApi()
                    } else {
                        root.errorMsg = i18n.tr("Not logged in")
                        root.isLoading = false
                    }
                } catch (e) {
                    console.log("Claude Usage: Failed to parse credentials:", e)
                    root.errorMsg = "Not logged in"
                    root.isLoading = false
                }
            } else {
                console.log("Claude Usage: No credentials file found")
                root.errorMsg = "Not logged in"
                root.isLoading = false
            }
        }
    }

    // Data source for launching claude in terminal
    Plasma5Support.DataSource {
        id: claudeLauncher
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            console.log("Claude Usage: Terminal launched")
        }
    }

    function loadCredentials() {
        root.isLoading = true
        root.errorMsg = ""
        var configBaseUrl = (Plasmoid.configuration.baseUrl || "").trim()
        if (configBaseUrl) {
            root.baseUrl = configBaseUrl.replace(/\/$/, "")
            root.apiKey = (Plasmoid.configuration.apiKey || "").trim()
            root.planName = "API Key"
            console.log("Claude Usage: Using configured base URL:", root.baseUrl)
            if (root.apiKey) {
                fetchUsageFromApi()
            } else {
                root.errorMsg = "API key not configured"
                root.isLoading = false
            }
        } else {
            root.baseUrl = ""
            root.apiKey = ""
            console.log("Claude Usage: No base URL configured, reading credentials file")
            fileReader.connectSource("cat $HOME/.claude/.credentials.json 2>/dev/null")
        }
    }

    function fetchUsageFromApi() {
        var url = root.baseUrl
            ? root.baseUrl + "/api/oauth/usage"
            : "https://api.anthropic.com/api/oauth/usage"

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.setRequestHeader("Content-Type", "application/json")

        xhr.setRequestHeader("anthropic-beta", "oauth-2025-04-20")

        if (root.baseUrl) {
            // Custom base URL: authenticate with API key
            xhr.setRequestHeader("x-api-key", root.apiKey)
        } else {
            // Default: OAuth token from credentials file
            xhr.setRequestHeader("Authorization", "Bearer " + root.accessToken)
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.isLoading = false

                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)

                        var fiveHour = data.five_hour || {}
                        var sevenDay = data.seven_day || {}

                        root.sessionUsagePercent = fiveHour.utilization || 0
                        root.weeklyUsagePercent = sevenDay.utilization || 0
                        root.hasSonnetData = !!data.seven_day_sonnet
                        root.hasOpusData = !!data.seven_day_opus
                        root.sonnetWeeklyPercent = root.hasSonnetData ? (data.seven_day_sonnet.utilization || 0) : 0
                        root.opusWeeklyPercent = root.hasOpusData ? (data.seven_day_opus.utilization || 0) : 0

                        if (fiveHour.resets_at) {
                            root.sessionResetTime = new Date(fiveHour.resets_at)
                            root.sessionReset = Qt.formatTime(root.sessionResetTime, "hh:mm")
                        }
                        if (sevenDay.resets_at) {
                            root.weeklyResetTime = new Date(sevenDay.resets_at)
                            root.weeklyReset = Qt.formatDateTime(root.weeklyResetTime, "MMM d, hh:mm")
                        }

                        root.lastUpdate = Qt.formatTime(new Date(), "hh:mm:ss")
                        root.errorMsg = ""
                        root.hasTokenError = false
                        root.hasRateLimitError = false

                        console.log("Claude Usage: API success - session:", root.sessionUsagePercent, "weekly:", root.weeklyUsagePercent)
                    } catch (e) {
                        console.log("Claude Usage: JSON parse error:", e)
                        root.errorMsg = "Parse error"
                    }
                } else if (xhr.status === 401) {
                    if (root.baseUrl) {
                        root.errorMsg = i18n.tr("Invalid API key")
                        console.log("Claude Usage: 401 Unauthorized - invalid API key")
                    } else {
                        console.log("Claude Usage: 401 Unauthorized - token expired")
                        root.hasTokenError = true
                        root.errorMsg = ""
                    }
                } else if (xhr.status === 404) {
                    root.errorMsg = root.baseUrl
                        ? i18n.tr("Endpoint not found")
                        : i18n.tr("API error") + " (404)"
                    console.log("Claude Usage: 404 Not Found:", url)
                } else if (xhr.status === 429) {
                    console.log("Claude Usage: 429 Rate limited")
                    root.hasRateLimitError = true
                    root.errorMsg = ""
                } else {
                    root.errorMsg = i18n.tr("API error") + " (" + xhr.status + ")"
                    console.log("Claude Usage: API error:", xhr.status, xhr.statusText)
                }
            }
        }

        xhr.send()
    }

    function refresh() {
        root.hasTokenError = false
        root.hasRateLimitError = false
        loadCredentials()
    }

    // Compact representation (panel) - shows both percentages
    compactRepresentation: Item {
        Layout.minimumWidth: usageRow.implicitWidth + Kirigami.Units.largeSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: usageRow.implicitWidth + Kirigami.Units.largeSpacing * 2

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }

        RowLayout {
            id: usageRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            // Claude icon with error indicator
            Item {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.rightMargin: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../icons/claude.svg")
                }

                // Red dot for token/rate limit error
                Rectangle {
                    visible: root.hasTokenError || root.hasRateLimitError
                    width: 8
                    height: 8
                    radius: 4
                    color: Kirigami.Theme.negativeTextColor
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -2
                    anchors.bottomMargin: -2
                }
            }

            // Error state (non-token errors)
            PlasmaComponents.Label {
                visible: root.errorMsg !== "" && !root.hasTokenError && !root.hasRateLimitError
                text: "⚠"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                color: Kirigami.Theme.negativeTextColor
            }

            // Normal state or token error state (show percentages)
            Rectangle {
                visible: root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: getUsageColor(root.sessionUsagePercent)
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : 1.0
            }

            PlasmaComponents.Label {
                visible: root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError
                text: Math.round(root.sessionUsagePercent) + "%"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                font.bold: true
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : 1.0
            }

            PlasmaComponents.Label {
                visible: root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError
                text: "|"
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.25 : 0.5
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            }

            Rectangle {
                visible: root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: getUsageColor(root.weeklyUsagePercent)
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : 1.0
            }

            PlasmaComponents.Label {
                visible: root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError
                text: Math.round(root.weeklyUsagePercent) + "%"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                font.bold: true
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : 1.0
            }

            // Error text (non-token errors only)
            PlasmaComponents.Label {
                visible: root.errorMsg !== "" && !root.hasTokenError && !root.hasRateLimitError
                text: root.errorMsg
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.negativeTextColor
            }
        }
    }

    // Full representation (popup)
    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 18

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.mediumSpacing

            // Header
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: i18n.tr("Claude Usage")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.3
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: planLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                    Layout.preferredHeight: planLabel.implicitHeight + Kirigami.Units.smallSpacing
                    radius: 3
                    color: Kirigami.Theme.highlightColor
                    PlasmaComponents.Label {
                        id: planLabel
                        anchors.centerIn: parent
                        text: root.planName
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.highlightedTextColor
                    }
                }
            }

            // Error message (regular errors)
            Rectangle {
                visible: root.errorMsg !== "" && !root.hasTokenError && !root.hasRateLimitError
                Layout.fillWidth: true
                Layout.preferredHeight: errorColumn.implicitHeight + Kirigami.Units.largeSpacing
                radius: 5
                color: Kirigami.Theme.negativeBackgroundColor

                ColumnLayout {
                    id: errorColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing

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

            // Token error message
            Rectangle {
                visible: root.hasTokenError
                Layout.fillWidth: true
                Layout.preferredHeight: tokenErrorColumn.implicitHeight + Kirigami.Units.largeSpacing
                radius: 5
                color: Kirigami.Theme.negativeBackgroundColor

                ColumnLayout {
                    id: tokenErrorColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: "⚠ " + i18n.tr("Token expired")
                        color: Kirigami.Theme.negativeTextColor
                        font.bold: true
                    }

                    PlasmaComponents.Button {
                        text: i18n.tr("Open Claude")
                        icon.name: "utilities-terminal"
                        onClicked: {
                            claudeLauncher.connectSource("bash -c 'cd $HOME && if command -v konsole >/dev/null; then konsole --hold -e env -u CLAUDECODE bash -lc claude; elif command -v gnome-terminal >/dev/null; then gnome-terminal -- env -u CLAUDECODE bash -lc \"claude; exec bash\"; elif command -v xfce4-terminal >/dev/null; then xfce4-terminal --hold -e \"env -u CLAUDECODE bash -lc claude\"; elif command -v xterm >/dev/null; then xterm -hold -e env -u CLAUDECODE bash -lc claude; fi &'")
                        }
                    }
                }
            }

            // Rate limit error message
            Rectangle {
                visible: root.hasRateLimitError
                Layout.fillWidth: true
                Layout.preferredHeight: rateLimitErrorColumn.implicitHeight + Kirigami.Units.largeSpacing
                radius: 5
                color: Kirigami.Theme.negativeBackgroundColor

                ColumnLayout {
                    id: rateLimitErrorColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: "⚠ " + i18n.tr("Rate limited")
                        color: Kirigami.Theme.negativeTextColor
                        font.bold: true
                    }

                    PlasmaComponents.Label {
                        text: i18n.tr("Auto-retry in 1 min")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.negativeTextColor
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.3
            }

            // Session Usage
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Session (5hr)")
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.sessionUsagePercent.toFixed(1) + "%"
                        color: getUsageColor(root.sessionUsagePercent)
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 10
                    radius: 5
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    border.width: 1
                    Rectangle {
                        width: parent.width * Math.min(root.sessionUsagePercent / 100, 1)
                        height: parent.height
                        radius: 5
                        color: getUsageColor(root.sessionUsagePercent)
                    }
                }

                PlasmaComponents.Label {
                    visible: root.sessionReset !== ""
                    text: i18n.tr("Resets at:") + " " + root.sessionReset + (root.sessionResetTime ? " (" + formatTimeRemaining(root.sessionResetTime) + ")" : "")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            // Weekly Usage
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Weekly (7day)")
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.weeklyUsagePercent.toFixed(1) + "%"
                        color: getUsageColor(root.weeklyUsagePercent)
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 10
                    radius: 5
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    border.width: 1
                    Rectangle {
                        width: parent.width * Math.min(root.weeklyUsagePercent / 100, 1)
                        height: parent.height
                        radius: 5
                        color: getUsageColor(root.weeklyUsagePercent)
                    }
                }

                PlasmaComponents.Label {
                    visible: root.weeklyReset !== ""
                    text: i18n.tr("Resets:") + " " + root.weeklyReset + (root.weeklyResetTime ? " (" + formatTimeRemaining(root.weeklyResetTime) + ")" : "")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.3
            }

            // Model breakdown
            PlasmaComponents.Label {
                text: i18n.tr("By Model (Weekly)")
                font.bold: true
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            // Sonnet
            RowLayout {
                Layout.fillWidth: true
                visible: root.hasSonnetData

                PlasmaComponents.Label {
                    text: i18n.tr("Sonnet")
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 60
                    height: 8
                    radius: 3
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    border.width: 1
                    Rectangle {
                        width: parent.width * Math.min(root.sonnetWeeklyPercent / 100, 1)
                        height: parent.height
                        radius: 3
                        color: getUsageColor(root.sonnetWeeklyPercent)
                    }
                }
                PlasmaComponents.Label {
                    text: root.sonnetWeeklyPercent.toFixed(0) + "%"
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Opus
            RowLayout {
                Layout.fillWidth: true
                visible: root.hasOpusData

                PlasmaComponents.Label {
                    text: i18n.tr("Opus")
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 60
                    height: 8
                    radius: 3
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    border.width: 1
                    Rectangle {
                        width: parent.width * Math.min(root.opusWeeklyPercent / 100, 1)
                        height: parent.height
                        radius: 3
                        color: getUsageColor(root.opusWeeklyPercent)
                    }
                }
                PlasmaComponents.Label {
                    text: root.opusWeeklyPercent.toFixed(0) + "%"
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }
            }

            // No model data message
            PlasmaComponents.Label {
                visible: !root.hasSonnetData && !root.hasOpusData
                text: i18n.tr("No model breakdown available")
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
                font.italic: true
            }

            Item { Layout.fillHeight: true }

            // Footer
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.3
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: root.lastUpdate !== "" ? i18n.tr("Updated:") + " " + root.lastUpdate : i18n.tr("Loading...")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                }
                Item { Layout.fillWidth: true }
                PlasmaComponents.Button {
                    icon.name: "view-refresh"
                    text: i18n.tr("Refresh")
                    onClicked: refresh()
                }
            }
        }
    }

    Timer {
        id: rateLimitRetryTimer
        interval: 60000
        running: root.hasRateLimitError
        repeat: false
        onTriggered: refresh()
    }

    Timer {
        id: refreshTimer
        interval: (Plasmoid.configuration.refreshInterval || 1) * 60000
        running: true
        repeat: true
        onTriggered: loadCredentials()
    }

    function getUsageColor(percent) {
        if (percent < 50) return Kirigami.Theme.positiveTextColor
        if (percent < 80) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.negativeTextColor
    }

    function formatTimeRemaining(resetTime) {
        if (!resetTime) return ""
        var now = new Date()
        var diff = resetTime.getTime() - now.getTime()
        if (diff <= 0) return ""

        var hours = Math.floor(diff / (1000 * 60 * 60))
        var minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))

        if (hours > 24) {
            var days = Math.floor(hours / 24)
            hours = hours % 24
            return days + i18n.tr("d") + " " + hours + i18n.tr("h")
        } else if (hours > 0) {
            return hours + i18n.tr("h") + " " + minutes + i18n.tr("m")
        } else {
            return minutes + i18n.tr("m")
        }
    }

    Component.onCompleted: {
        console.log("Claude Usage: Widget loaded")
        loadCredentials()
    }

    Plasmoid.icon: "claude-usage"
    toolTipMainText: i18n.tr("Claude Usage")
    toolTipSubText: i18n.tr("Session (5hr)") + ": " + Math.round(root.sessionUsagePercent) + "% | " + i18n.tr("Weekly (7day)") + ": " + Math.round(root.weeklyUsagePercent) + "%"
}
