import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.core as PlasmaCore

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
    property int rateLimitRetryCount: 0
    property int rateLimitRetryMs: 0  // from retry-after header
    property double lastFetchTime: 0
    property double lastSuccessTime: 0
    property bool isStale: false
    readonly property int minFetchIntervalMs: 55000  // just under 1 minute
    // Stale threshold: if rate limited, use retry-after + buffer; otherwise 3x refresh interval
    readonly property int staleThresholdMs: root.hasRateLimitError && root.rateLimitRetryMs > 0
        ? root.rateLimitRetryMs + 60000
        : Math.max(Plasmoid.configuration.refreshInterval || 1, 1) * 60000 * 3

    // Cache writer - saves last successful data to file
    Plasma5Support.DataSource {
        id: cacheWriter
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName) }
    }

    // Cache reader - loads cached data on startup
    Plasma5Support.DataSource {
        id: cacheReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (stdout.length > 10) {
                try {
                    var cache = JSON.parse(stdout)
                    var age = Date.now() - (cache.timestamp || 0)
                    if (age < 86400000) { // less than 24 hours old
                        root.sessionUsagePercent = cache.session || 0
                        root.weeklyUsagePercent = cache.weekly || 0
                        root.sonnetWeeklyPercent = cache.sonnet || 0
                        root.opusWeeklyPercent = cache.opus || 0
                        root.hasSonnetData = cache.hasSonnet || false
                        root.hasOpusData = cache.hasOpus || false
                        root.planName = cache.plan || ""
                        root.sessionReset = cache.sessionReset || ""
                        root.weeklyReset = cache.weeklyReset || ""
                        root.sessionResetTime = cache.sessionResetTs ? new Date(cache.sessionResetTs) : null
                        root.weeklyResetTime = cache.weeklyResetTs ? new Date(cache.weeklyResetTs) : null
                        root.lastSuccessTime = cache.timestamp
                        root.lastUpdate = Qt.formatTime(new Date(cache.timestamp), "hh:mm:ss") + " *"
                        root.isStale = age > root.staleThresholdMs
                        console.log("Claude Usage: Loaded cache, age:", Math.round(age/60000), "min, stale:", root.isStale)
                    } else {
                        console.log("Claude Usage: Cache too old, ignoring")
                    }
                } catch (e) {
                    console.log("Claude Usage: Cache parse error:", e)
                }
            }
        }
    }

    function saveCache() {
        var cache = {
            session: root.sessionUsagePercent,
            weekly: root.weeklyUsagePercent,
            sonnet: root.sonnetWeeklyPercent,
            opus: root.opusWeeklyPercent,
            hasSonnet: root.hasSonnetData,
            hasOpus: root.hasOpusData,
            plan: root.planName,
            sessionReset: root.sessionReset,
            weeklyReset: root.weeklyReset,
            sessionResetTs: root.sessionResetTime ? root.sessionResetTime.getTime() : null,
            weeklyResetTs: root.weeklyResetTime ? root.weeklyResetTime.getTime() : null,
            timestamp: Date.now()
        }
        var json = JSON.stringify(cache)
        cacheWriter.connectSource("echo '" + json.replace(/'/g, "'\\''") + "' > $HOME/.local/share/claude-usage-cache.json")
    }

    // Stale checker - updates isStale flag periodically
    Timer {
        id: staleTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            if (root.lastSuccessTime > 0) {
                root.isStale = (Date.now() - root.lastSuccessTime) > root.staleThresholdMs
            }
        }
    }

    // Token watcher - polls credentials file during rate limit to detect token refresh
    Plasma5Support.DataSource {
        id: tokenWatcher
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (stdout.length > 10) {
                try {
                    var creds = JSON.parse(stdout)
                    var newToken = (creds.claudeAiOauth || {}).accessToken || ""
                    if (newToken && newToken !== root.accessToken) {
                        console.log("Claude Usage: New token detected! Resetting rate limit state.")
                        root.accessToken = newToken
                        root.hasRateLimitError = false
                        root.rateLimitRetryCount = 0
                        root.lastFetchTime = 0
                        fetchUsageFromApi(true)
                    }
                } catch (e) {
                    console.log("Claude Usage: Token watcher parse error:", e)
                }
            }
        }
    }

    Timer {
        id: tokenWatchTimer
        interval: 30000  // check every 30 seconds
        running: root.hasRateLimitError && !root.baseUrl
        repeat: true
        onTriggered: {
            tokenWatcher.connectSource("cat $HOME/.claude/.credentials.json 2>/dev/null")
        }
    }

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

    // Data source for detecting Claude Code version
    property string claudeVersion: ""
    property string userAgent: "claude-code/" + Qt.formatDateTime(new Date(), "yyyy.M.d")

    Plasma5Support.DataSource {
        id: versionReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            // Output format: "2.1.81 (Claude Code)"
            var match = stdout.match(/^(\d+\.\d+\.\d+)/)
            if (match) {
                root.claudeVersion = match[1]
                root.userAgent = "claude-code/" + match[1]
                console.log("Claude Usage: Detected version:", root.claudeVersion)
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

    function fetchUsageFromApi(force) {
        var now = Date.now()
        if (!force && root.lastFetchTime > 0 && (now - root.lastFetchTime) < root.minFetchIntervalMs) {
            console.log("Claude Usage: Skipping fetch, too soon since last request")
            root.isLoading = false
            return
        }
        root.lastFetchTime = now

        var url = root.baseUrl
            ? root.baseUrl + "/api/oauth/usage"
            : "https://api.anthropic.com/api/oauth/usage"

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("User-Agent", root.userAgent)
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
                        root.lastSuccessTime = Date.now()
                        root.isStale = false
                        root.errorMsg = ""
                        root.hasTokenError = false
                        root.hasRateLimitError = false
                        root.rateLimitRetryCount = 0
                        root.rateLimitRetryMs = 0
                        saveCache()

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
                    var retryAfter = parseInt(xhr.getResponseHeader("retry-after") || "0")
                    if (retryAfter > 0) {
                        root.rateLimitRetryMs = retryAfter * 1000
                    }
                    root.rateLimitRetryCount++
                    console.log("Claude Usage: 429 Rate limited (retry #" + root.rateLimitRetryCount + ", retry-after: " + retryAfter + "s, waiting: " + root.rateLimitBackoffMs/1000 + "s)")
                    root.hasRateLimitError = true
                    root.lastFetchTime = 0  // allow retry timer to work
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
        root.rateLimitRetryCount = 0
        root.rateLimitRetryMs = 0
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
                visible: Plasmoid.configuration.showIcon !== false
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

            // === TEXT STYLE ===

            // Session usage (text)
            Rectangle {
                visible: (!Plasmoid.configuration.panelStyle || Plasmoid.configuration.panelStyle === "text") && (Plasmoid.configuration.showSession !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: getUsageColor(root.sessionUsagePercent)
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            }

            PlasmaComponents.Label {
                visible: (!Plasmoid.configuration.panelStyle || Plasmoid.configuration.panelStyle === "text") && (Plasmoid.configuration.showSession !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                text: Math.round(root.sessionUsagePercent) + "%"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                font.bold: true
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            }

            // Separator session-weekly (text)
            PlasmaComponents.Label {
                visible: (!Plasmoid.configuration.panelStyle || Plasmoid.configuration.panelStyle === "text") && (Plasmoid.configuration.showSession !== false) && (Plasmoid.configuration.showWeekly !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                text: "|"
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.25 : root.isStale ? 0.35 : 0.5
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            }

            // Weekly usage (text)
            Rectangle {
                visible: (!Plasmoid.configuration.panelStyle || Plasmoid.configuration.panelStyle === "text") && (Plasmoid.configuration.showWeekly !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: getUsageColor(root.weeklyUsagePercent)
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            }

            PlasmaComponents.Label {
                visible: (!Plasmoid.configuration.panelStyle || Plasmoid.configuration.panelStyle === "text") && (Plasmoid.configuration.showWeekly !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                text: Math.round(root.weeklyUsagePercent) + "%"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                font.bold: true
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            }

            // Separator before sonnet (text)
            PlasmaComponents.Label {
                visible: (!Plasmoid.configuration.panelStyle || Plasmoid.configuration.panelStyle === "text") && (Plasmoid.configuration.showSonnet === true) && ((Plasmoid.configuration.showSession !== false) || (Plasmoid.configuration.showWeekly !== false)) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                text: "|"
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.25 : root.isStale ? 0.35 : 0.5
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            }

            // Sonnet usage (text)
            Rectangle {
                visible: (!Plasmoid.configuration.panelStyle || Plasmoid.configuration.panelStyle === "text") && (Plasmoid.configuration.showSonnet === true) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: getUsageColor(root.sonnetWeeklyPercent)
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            }

            PlasmaComponents.Label {
                visible: (!Plasmoid.configuration.panelStyle || Plasmoid.configuration.panelStyle === "text") && (Plasmoid.configuration.showSonnet === true) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                text: Math.round(root.sonnetWeeklyPercent) + "%"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                font.bold: true
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0
            }

            // === CIRCULAR STYLE ===

            // Session (circular)
            Item {
                visible: Plasmoid.configuration.panelStyle === "circular" && (Plasmoid.configuration.showSession !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        drawCircularProgress(ctx, width, height, root.sessionUsagePercent)
                    }
                    property real _percent: root.sessionUsagePercent
                    on_PercentChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: Math.round(root.sessionUsagePercent)
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            // Weekly (circular)
            Item {
                visible: Plasmoid.configuration.panelStyle === "circular" && (Plasmoid.configuration.showWeekly !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        drawCircularProgress(ctx, width, height, root.weeklyUsagePercent)
                    }
                    property real _percent: root.weeklyUsagePercent
                    on_PercentChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: Math.round(root.weeklyUsagePercent)
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            // Sonnet (circular)
            Item {
                visible: Plasmoid.configuration.panelStyle === "circular" && (Plasmoid.configuration.showSonnet === true) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                opacity: (root.hasTokenError || root.hasRateLimitError) ? 0.5 : root.isStale ? 0.6 : 1.0

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        drawCircularProgress(ctx, width, height, root.sonnetWeeklyPercent)
                    }
                    property real _percent: root.sonnetWeeklyPercent
                    on_PercentChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: Math.round(root.sonnetWeeklyPercent)
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            // === BAR STYLE ===

            // Session (bar)
            Item {
                visible: Plasmoid.configuration.panelStyle === "bar" && (Plasmoid.configuration.showSession !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
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
                        color: getUsageColor(root.sessionUsagePercent)
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: Math.round(root.sessionUsagePercent)
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            // Weekly (bar)
            Item {
                visible: Plasmoid.configuration.panelStyle === "bar" && (Plasmoid.configuration.showWeekly !== false) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
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
                        color: getUsageColor(root.weeklyUsagePercent)
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: Math.round(root.weeklyUsagePercent)
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            // Sonnet (bar)
            Item {
                visible: Plasmoid.configuration.panelStyle === "bar" && (Plasmoid.configuration.showSonnet === true) && (root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError)
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
                        height: Math.max((parent.height - 2) * Math.min(root.sonnetWeeklyPercent / 100, 1), 1)
                        radius: 2
                        color: getUsageColor(root.sonnetWeeklyPercent)
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: Math.round(root.sonnetWeeklyPercent)
                    font.pixelSize: 9
                    font.bold: true
                }
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
                        text: i18n.tr("Auto-retry in") + " " + Math.round(root.rateLimitBackoffMs / 60000) + " min"
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
                        text: Math.round(root.sessionUsagePercent) + "%"
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
                        text: Math.round(root.weeklyUsagePercent) + "%"
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
                    text: Math.round(root.sonnetWeeklyPercent) + "%"
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
                    text: Math.round(root.opusWeeklyPercent) + "%"
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

            // Rate limit warning
            PlasmaComponents.Label {
                visible: (Plasmoid.configuration.refreshInterval || 5) < 5
                text: "⚠ " + i18n.tr("Values under 5 min may cause rate limiting")
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.neutralTextColor
                font.italic: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
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
        interval: root.rateLimitBackoffMs
        running: root.hasRateLimitError
        repeat: true
        onTriggered: {
            console.log("Claude Usage: Backoff retry, interval:", interval/1000, "s")
            loadCredentials()
        }
    }

    // Use retry-after header if available, otherwise fallback to 5min steps (capped at 15min)
    readonly property int rateLimitBackoffMs: root.rateLimitRetryMs > 0
        ? root.rateLimitRetryMs + 10000  // retry-after + 10s buffer
        : Math.min((root.rateLimitRetryCount + 1) * 300000, 900000)

    Timer {
        id: refreshTimer
        interval: Math.max(Plasmoid.configuration.refreshInterval || 5, 1) * 60000
        running: !root.hasRateLimitError
        repeat: true
        onTriggered: loadCredentials()
    }

    function drawCircularProgress(ctx, w, h, percent) {
        var centerX = w / 2
        var centerY = h / 2
        var radius = Math.min(w, h) / 2 - 2
        var lineWidth = 3
        var startAngle = -Math.PI / 2
        var endAngle = startAngle + (2 * Math.PI * Math.min(percent, 100) / 100)

        ctx.reset()

        // Background circle
        ctx.beginPath()
        ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
        ctx.strokeStyle = Kirigami.Theme.disabledTextColor
        ctx.globalAlpha = 0.3
        ctx.lineWidth = lineWidth
        ctx.stroke()

        // Progress arc
        if (percent > 0) {
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, startAngle, endAngle)
            ctx.strokeStyle = getUsageColor(percent)
            ctx.globalAlpha = 1.0
            ctx.lineWidth = lineWidth
            ctx.lineCap = "round"
            ctx.stroke()
        }
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

    // Install icon to system theme for about page
    Plasma5Support.DataSource {
        id: iconInstaller
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName) }
    }

    Component.onCompleted: {
        console.log("Claude Usage: Widget loaded")
        var iconSource = Qt.resolvedUrl("../icons/claude-usage-widget.svg").toString().replace("file://", "")
        iconInstaller.connectSource("bash -c 'ICON_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps && mkdir -p $ICON_DIR && cp \"" + iconSource + "\" $ICON_DIR/claude-usage-widget.svg && chmod 644 $ICON_DIR/claude-usage-widget.svg 2>/dev/null'")
        cacheReader.connectSource("cat $HOME/.local/share/claude-usage-cache.json 2>/dev/null")
        versionReader.connectSource("claude --version 2>/dev/null")
        loadCredentials()
    }

    // Only use custom background on desktop, panel keeps default Plasma background
    readonly property bool isOnPanel: Plasmoid.location === PlasmaCore.Types.TopEdge
        || Plasmoid.location === PlasmaCore.Types.BottomEdge
        || Plasmoid.location === PlasmaCore.Types.LeftEdge
        || Plasmoid.location === PlasmaCore.Types.RightEdge

    Plasmoid.backgroundHints: isOnPanel ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground

    // Custom background with configurable opacity (desktop only)
    Rectangle {
        visible: !root.isOnPanel
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        opacity: Plasmoid.configuration.backgroundOpacity
        radius: Kirigami.Units.cornerRadius
    }

    Plasmoid.icon: "claude-usage-widget"
    toolTipMainText: i18n.tr("Claude Usage")
    toolTipSubText: {
        var parts = []
        if (Plasmoid.configuration.showSession !== false)
            parts.push(i18n.tr("Session (5hr)") + ": " + Math.round(root.sessionUsagePercent) + "%")
        if (Plasmoid.configuration.showWeekly !== false)
            parts.push(i18n.tr("Weekly (7day)") + ": " + Math.round(root.weeklyUsagePercent) + "%")
        if (Plasmoid.configuration.showSonnet === true)
            parts.push(i18n.tr("Sonnet") + ": " + Math.round(root.sonnetWeeklyPercent) + "%")
        return parts.join(" | ")
    }
}
