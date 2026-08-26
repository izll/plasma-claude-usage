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
    property var modelLimits: []
    property var parsedQuickLinks: []

    function isModelShownInPanel(modelLabel) {
        var shown = (Plasmoid.configuration.showModelLimits || "").toString()
        if (!shown) return false
        var list = shown.split(",")
        for (var i = 0; i < list.length; i++) {
            if (list[i].trim() === modelLabel) return true
        }
        return false
    }

    function reloadQuickLinks() {
        try { parsedQuickLinks = JSON.parse(Plasmoid.configuration.quickLinks || "[]") }
        catch (e) { parsedQuickLinks = [] }
    }

    Connections {
        target: Plasmoid.configuration
        function onQuickLinksChanged() { root.reloadQuickLinks() }
    }

    property bool claudeRunning: true
    readonly property bool showUsageStats: {
        var vis = Plasmoid.configuration.processVisibility || "always"
        return vis === "always" || root.claudeRunning
    }

    property bool hasTokenError: false
    property bool hasRateLimitError: false
    property int rateLimitRetryCount: 0
    property int rateLimitRetryMs: 0
    property double lastFetchTime: 0
    property double lastSuccessTime: 0
    property bool isStale: false
    readonly property int minFetchIntervalMs: 55000
    readonly property int staleThresholdMs: root.hasRateLimitError && root.rateLimitRetryMs > 0
        ? root.rateLimitRetryMs + 60000
        : Math.max(Plasmoid.configuration.refreshInterval || 1, 1) * 60000 * 3

    // v2.0: dynamic model breakdown, trend history, account email, update check
    property var modelUsage: []
    property var usageSamples: []
    property string accountEmail: ""
    property string latestVersion: ""
    readonly property bool updateAvailable: root.claudeVersion !== "" && root.latestVersion !== ""
        && isNewerVersion(root.latestVersion, root.claudeVersion)
    readonly property bool metricsVisible: root.errorMsg === "" || root.hasTokenError || root.hasRateLimitError

    property string accountTier: ""
    property string credsTier: ""
    property string credsSub: ""

    property var tokenStats: []

    // v2.1: time-aware coloring, extra usage, installations, notifications
    property double nowTick: Date.now()
    readonly property real sessionTimePct: elapsedPct(root.sessionResetTime, 18000000)
    readonly property real weeklyTimePct: elapsedPct(root.weeklyResetTime, 604800000)
    property bool extraEnabled: false
    property real extraUsedCents: 0
    property real extraLimitCents: 0
    readonly property real extraPercent: root.extraLimitCents > 0 ? root.extraUsedCents / root.extraLimitCents * 100 : 0
    property var installations: []
    property var alertedThresholds: ({})

    // Cache writer
    Plasma5Support.DataSource {
        id: cacheWriter
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName) }
    }

    // Cache reader
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
                    if (age < 86400000) {
                        root.sessionUsagePercent = cache.session || 0
                        root.weeklyUsagePercent = cache.weekly || 0
                        root.sonnetWeeklyPercent = cache.sonnet || 0
                        root.opusWeeklyPercent = cache.opus || 0
                        root.hasSonnetData = cache.hasSonnet || false
                        root.hasOpusData = cache.hasOpus || false
                        if (cache.modelLimits) {
                            root.modelLimits = cache.modelLimits
                        } else {
                            var legacyLimits = []
                            if (cache.hasSonnet) legacyLimits.push({ label: "Sonnet", percent: cache.sonnet || 0 })
                            if (cache.hasOpus) legacyLimits.push({ label: "Opus", percent: cache.opus || 0 })
                            root.modelLimits = legacyLimits
                        }
                        root.modelUsage = cache.models || []
                        root.usageSamples = cache.samples || []
                        root.extraEnabled = cache.extraEnabled || false
                        root.extraUsedCents = cache.extraUsed || 0
                        root.extraLimitCents = cache.extraLimit || 0
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
            modelLimits: root.modelLimits,
            plan: root.planName,
            sessionReset: root.sessionReset,
            weeklyReset: root.weeklyReset,
            sessionResetTs: root.sessionResetTime ? root.sessionResetTime.getTime() : null,
            weeklyResetTs: root.weeklyResetTime ? root.weeklyResetTime.getTime() : null,
            models: root.modelUsage,
            samples: root.usageSamples,
            extraEnabled: root.extraEnabled,
            extraUsed: root.extraUsedCents,
            extraLimit: root.extraLimitCents,
            timestamp: Date.now()
        }
        var json = JSON.stringify(cache)
        cacheWriter.connectSource("echo '" + json.replace(/'/g, "'\\''") + "' > $HOME/.local/share/claude-usage-cache.json")
    }

    // Stale checker
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

    // Token watcher
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
        interval: 30000
        running: root.hasRateLimitError && !root.baseUrl
        repeat: true
        onTriggered: {
            tokenWatcher.connectSource("cat $HOME/.claude/.credentials.json 2>/dev/null")
        }
    }

    // Process checker (visibility feature)
    Plasma5Support.DataSource {
        id: processChecker
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = data["stdout"] || ""
            disconnectSource(sourceName)

            var wasRunning = root.claudeRunning
            root.claudeRunning = stdout.trim().length > 0

            var vis = Plasmoid.configuration.processVisibility || "always"
            if (vis === "fully_hidden") {
                Plasmoid.status = root.claudeRunning
                    ? PlasmaCore.Types.ActiveStatus
                    : PlasmaCore.Types.HiddenStatus
            }

            if (root.claudeRunning && !wasRunning) {
                loadCredentials()
            }
        }
    }

    function checkClaudeProcess() {
        processChecker.connectSource("pgrep -x claude 2>/dev/null")
    }

    function updateProcessVisibility() {
        var vis = Plasmoid.configuration.processVisibility || "always"
        if (vis === "always") {
            root.claudeRunning = true
            Plasmoid.status = PlasmaCore.Types.ActiveStatus
        } else if (vis === "hide_usage") {
            Plasmoid.status = PlasmaCore.Types.ActiveStatus
            checkClaudeProcess()
        } else {
            Plasmoid.status = PlasmaCore.Types.HiddenStatus
            checkClaudeProcess()
        }
    }

    Timer {
        id: processCheckTimer
        interval: Math.max(Plasmoid.configuration.processCheckInterval || 30, 5) * 1000
        running: (Plasmoid.configuration.processVisibility || "always") !== "always"
        repeat: true
        onTriggered: checkClaudeProcess()
    }

    Connections {
        target: Plasmoid.configuration
        function onProcessVisibilityChanged() {
            updateProcessVisibility()
        }
    }

    // Credentials reader
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

                    root.credsTier = oauth.rateLimitTier || ""
                    root.credsSub = oauth.subscriptionType || ""
                    updatePlanName()

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

    // Version detection
    property string claudeVersion: ""
    property string userAgent: "claude-code/" + Qt.formatDateTime(new Date(), "yyyy.M.d")

    Plasma5Support.DataSource {
        id: versionReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            var match = stdout.match(/^(\d+\.\d+\.\d+)/)
            if (match) {
                root.claudeVersion = match[1]
                root.userAgent = "claude-code/" + match[1]
                console.log("Claude Usage: Detected version:", root.claudeVersion)
                refreshInstallations()
            }
        }
    }

    // Account email reader
    Plasma5Support.DataSource {
        id: emailReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (stdout.length > 2) {
                try {
                    var acct = JSON.parse(stdout).oauthAccount || {}
                    root.accountEmail = acct.emailAddress || ""
                    root.accountTier = acct.userRateLimitTier || acct.organizationRateLimitTier || ""
                    updatePlanName()
                } catch (e) {
                    console.log("Claude Usage: account info parse error:", e)
                }
            }
        }
    }

    // Update check timer
    Timer {
        id: updateCheckTimer
        interval: 21600000
        running: Plasmoid.configuration.enableUpdateCheck !== false
        repeat: true
        onTriggered: checkForUpdate()
    }

    // Token stats reader (pure QML, no python)
    Plasma5Support.DataSource {
        id: tokenStatsReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (stdout.length < 2) return
            try {
                root.tokenStats = parseTokenStatsOutput(stdout)
            } catch (e) {
                console.log("Claude Usage: token stats parse error:", e)
            }
        }
    }

    function parseTokenStatsOutput(raw) {
        var lines = raw.split("\n")
        var models = {}
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("|")
            if (parts.length < 5) continue
            var model = parts[0]
            if (!models[model]) models[model] = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
            models[model].input += parseInt(parts[1]) || 0
            models[model].output += parseInt(parts[2]) || 0
            models[model].cacheRead += parseInt(parts[3]) || 0
            models[model].cacheWrite += parseInt(parts[4]) || 0
        }
        var stats = []
        for (var m in models) {
            var u = models[m]
            stats.push({
                model: m,
                name: prettyModelName(m),
                total: u.input + u.output + u.cacheRead + u.cacheWrite,
                output: u.output
            })
        }
        return sortModels(stats, "model")
    }

    Timer {
        id: tokenStatsTimer
        interval: 900000
        running: true
        repeat: true
        onTriggered: refreshTokenStats()
    }

    Timer {
        id: clockTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.nowTick = Date.now()
    }

    // Installations reader
    Plasma5Support.DataSource {
        id: installsReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            var found = []
            if (root.claudeVersion !== "") {
                found.push({ name: "CLI", version: root.claudeVersion })
            }
            if (stdout.length > 0) {
                var lines = stdout.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|")
                    if (parts.length === 2 && parts[1]) {
                        found.push({ name: parts[0], version: parts[1] })
                    }
                }
            }
            root.installations = found
        }
    }

    function refreshInstallations() {
        installsReader.connectSource("bash -c 'for p in \"VS Code:.vscode\" \"Cursor:.cursor\" \"Windsurf:.windsurf\"; do n=\"${p%%:*}\"; d=\"$HOME/${p#*:}/extensions\"; v=$(ls -d \"$d\"/anthropic.claude-code-* 2>/dev/null | sed -e \"s/.*claude-code-//\" -e \"s/-[a-z].*//\" | sort -V | tail -n1); [ -n \"$v\" ] && printf \"%s|%s\\n\" \"$n\" \"$v\"; done; true'")
    }

    // Desktop notifications
    Plasma5Support.DataSource {
        id: notifier
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName) }
    }

    function sendNotification(title, body) {
        if (Plasmoid.configuration.enableNotifications === false) return
        var esc = function(s) { return String(s).replace(/'/g, "'\\''") }
        notifier.connectSource("notify-send -a 'Claude Usage' -i claude-usage-widget '" + esc(title) + "' '" + esc(body) + "'")
    }

    function refreshTokenStats() {
        var today = Qt.formatDateTime(new Date(), "yyyy-MM-dd")
        var script = "bash -c 'find $HOME/.claude/projects -name \"*.jsonl\" -newer /tmp/.claude-token-stats-marker -o -name \"*.jsonl\" 2>/dev/null | head -50 | while read f; do grep -o '\\''\"model\":\"[^\"]*\".*\"input_tokens\":[0-9]*.*\"output_tokens\":[0-9]*'\\'' \"$f\" 2>/dev/null; done | grep '\\''\"" + today + "'\\'' | sed -E '\\''s/.*\"model\":\"([^\"]*)\".*\"input_tokens\":([0-9]+).*\"output_tokens\":([0-9]+).*/\\1|\\2|\\3|0|0/'\\'' 2>/dev/null; true'"
        tokenStatsReader.connectSource(script)
    }

    // Terminal launcher
    Plasma5Support.DataSource {
        id: claudeLauncher
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            console.log("Claude Usage: Terminal launched")
        }
    }

    function launchInTerminal(cmd) {
        claudeLauncher.connectSource("bash -c 'cd $HOME && if command -v konsole >/dev/null; then konsole --hold -e env -u CLAUDECODE bash -lc \"" + cmd + "\"; elif command -v gnome-terminal >/dev/null; then gnome-terminal -- env -u CLAUDECODE bash -lc \"" + cmd + "; exec bash\"; elif command -v xfce4-terminal >/dev/null; then xfce4-terminal --hold -e \"env -u CLAUDECODE bash -lc \\\"" + cmd + "\\\"\"; elif command -v xterm >/dev/null; then xterm -hold -e env -u CLAUDECODE bash -lc \"" + cmd + "\"; fi &'")
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
            xhr.setRequestHeader("x-api-key", root.apiKey)
        } else {
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

                        // Model breakdown from limits array (newer API)
                        var limits = []
                        if (data.limits && data.limits.length > 0) {
                            for (var i = 0; i < data.limits.length; i++) {
                                var entry = data.limits[i]
                                if (entry.kind === "session" || entry.kind === "weekly_all") continue
                                var scope = entry.scope || {}
                                var label = (scope.model && scope.model.display_name) || scope.surface || entry.kind
                                limits.push({ label: label, percent: entry.percent || 0 })
                            }
                        } else {
                            if (data.seven_day_sonnet) limits.push({ label: "Sonnet", percent: data.seven_day_sonnet.utilization || 0 })
                            if (data.seven_day_opus) limits.push({ label: "Opus", percent: data.seven_day_opus.utilization || 0 })
                        }
                        root.modelLimits = limits

                        // Model breakdown from seven_day_* keys (for card view)
                        var nonModelKeys = ["oauth_apps", "cowork", "omelette"]
                        var models = []
                        for (var key in data) {
                            var m = key.match(/^seven_day_(.+)$/)
                            if (m && nonModelKeys.indexOf(m[1]) !== -1) continue
                            if (m && data[key] && typeof data[key] === "object") {
                                models.push({
                                    key: m[1],
                                    name: modelDisplayName(m[1]),
                                    percent: data[key].utilization || 0
                                })
                            }
                        }
                        root.modelUsage = sortModels(models, "key")

                        root.hasSonnetData = !!data.seven_day_sonnet
                        root.hasOpusData = !!data.seven_day_opus
                        root.sonnetWeeklyPercent = root.hasSonnetData ? (data.seven_day_sonnet.utilization || 0) : 0
                        root.opusWeeklyPercent = root.hasOpusData ? (data.seven_day_opus.utilization || 0) : 0

                        // Extra usage (paid overage budget)
                        var extra = data.extra_usage || {}
                        root.extraEnabled = !!extra.is_enabled && (extra.monthly_limit || 0) > 0
                        root.extraUsedCents = extra.used_credits || 0
                        root.extraLimitCents = extra.monthly_limit || 0

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

                        // Trend history
                        var samples = root.usageSamples.slice()
                        var nowTs = Date.now()
                        if (samples.length === 0 || nowTs - samples[samples.length - 1].t >= 900000) {
                            samples.push({ t: nowTs, session: root.sessionUsagePercent, weekly: root.weeklyUsagePercent })
                        }
                        root.usageSamples = samples.filter(function(s) { return nowTs - s.t < 604800000 })

                        root.nowTick = Date.now()
                        checkAlerts()
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
                        root.hasRateLimitError = false
                        root.errorMsg = ""
                    }
                } else if (xhr.status === 403) {
                    console.log("Claude Usage: 403 Permission error - token lacks required scope (re-login needed)")
                    root.hasTokenError = true
                    root.hasRateLimitError = false
                    root.rateLimitRetryCount = 0
                    root.errorMsg = ""
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
                    root.lastFetchTime = 0
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

    // Compact representation (panel)
    readonly property bool isVerticalLayout: Plasmoid.configuration.panelLayout === "vertical"
    readonly property string effectivePanelStyle: {
        var s = Plasmoid.configuration.panelStyle || "ring"
        return s === "circular" ? "ring" : s
    }
    readonly property bool useTimeAware: Plasmoid.configuration.useTimeAwareColors !== false

    compactRepresentation: CompactView {}

    // Full representation (popup) - switchable between classic and card
    readonly property bool useCardPopup: (Plasmoid.configuration.popupStyle || "card") === "card"

    fullRepresentation: Item {
        id: fullRepItem

        property real targetWidth: root.useCardPopup
            ? (cardLoader.item ? cardLoader.item.Layout.preferredWidth : Kirigami.Units.gridUnit * 17)
            : Kirigami.Units.gridUnit * 16
        property real targetHeight: root.useCardPopup
            ? (cardLoader.item ? cardLoader.item.Layout.preferredHeight : Kirigami.Units.gridUnit * 20)
            : classicColumn.implicitHeight + Kirigami.Units.largeSpacing * 2

        Layout.minimumWidth: root.useCardPopup
            ? (cardLoader.item ? cardLoader.item.Layout.minimumWidth : Kirigami.Units.gridUnit * 16)
            : Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: root.useCardPopup
            ? (cardLoader.item ? cardLoader.item.Layout.minimumHeight : Kirigami.Units.gridUnit * 16)
            : Math.min(classicColumn.implicitHeight + Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 24)
        Layout.preferredWidth: targetWidth
        Layout.preferredHeight: targetHeight
        Layout.maximumWidth: resizeForcer.running ? targetWidth : -1
        Layout.maximumHeight: resizeForcer.running ? targetHeight : -1

        onTargetWidthChanged: resizeForcer.restart()
        onTargetHeightChanged: resizeForcer.restart()

        Timer {
            id: resizeForcer
            interval: 150
        }

        Loader {
            id: cardLoader
            anchors.fill: parent
            anchors.margins: root.useCustomBackground ? Kirigami.Units.mediumSpacing : 0
            active: root.useCardPopup
            source: "FullView.qml"
        }

        Item {
            anchors.fill: parent
            anchors.margins: root.useCustomBackground ? Kirigami.Units.mediumSpacing : 0
            visible: !root.useCardPopup

            ColumnLayout {
                id: classicColumn
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
                            Layout.preferredWidth: classicPlanLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                            Layout.preferredHeight: classicPlanLabel.implicitHeight + Kirigami.Units.smallSpacing
                            radius: 3
                            color: Kirigami.Theme.highlightColor
                            PlasmaComponents.Label {
                                id: classicPlanLabel
                                anchors.centerIn: parent
                                text: root.planName
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                color: Kirigami.Theme.highlightedTextColor
                            }
                        }
                    }

                    // Error message
                    Rectangle {
                        visible: root.errorMsg !== "" && !root.hasTokenError && !root.hasRateLimitError
                        Layout.fillWidth: true
                        Layout.preferredHeight: classicErrorCol.implicitHeight + Kirigami.Units.largeSpacing
                        radius: 5
                        color: Kirigami.Theme.negativeBackgroundColor

                        ColumnLayout {
                            id: classicErrorCol
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

                    // Token error
                    Rectangle {
                        visible: root.hasTokenError
                        Layout.fillWidth: true
                        Layout.preferredHeight: classicTokenErrorCol.implicitHeight + Kirigami.Units.largeSpacing
                        radius: 5
                        color: Kirigami.Theme.negativeBackgroundColor

                        ColumnLayout {
                            id: classicTokenErrorCol
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
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

                    // Rate limit error
                    Rectangle {
                        visible: root.hasRateLimitError
                        Layout.fillWidth: true
                        Layout.preferredHeight: classicRateLimitCol.implicitHeight + Kirigami.Units.largeSpacing
                        radius: 5
                        color: Kirigami.Theme.negativeBackgroundColor

                        ColumnLayout {
                            id: classicRateLimitCol
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
                                color: root.getUsageColor(root.sessionUsagePercent, root.useTimeAware ? root.sessionTimePct : undefined)
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
                                color: root.getUsageColor(root.sessionUsagePercent, root.useTimeAware ? root.sessionTimePct : undefined)
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
                                color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
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
                                color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
                            }
                        }

                        PlasmaComponents.Label {
                            visible: root.weeklyReset !== ""
                            text: i18n.tr("Resets:") + " " + root.weeklyReset + (root.weeklyResetTime ? " (" + formatTimeRemaining(root.weeklyResetTime) + ")" : "")
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

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

                    Repeater {
                        model: root.modelLimits

                        RowLayout {
                            id: classicLimitRow
                            required property var modelData
                            Layout.fillWidth: true

                            PlasmaComponents.Label {
                                text: classicLimitRow.modelData.label
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
                                    width: parent.width * Math.min(classicLimitRow.modelData.percent / 100, 1)
                                    height: parent.height
                                    radius: 3
                                    color: root.getUsageColor(classicLimitRow.modelData.percent, root.useTimeAware ? root.weeklyTimePct : undefined)
                                }
                            }
                            PlasmaComponents.Label {
                                text: Math.round(classicLimitRow.modelData.percent) + "%"
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        visible: root.modelLimits.length === 0
                        text: i18n.tr("No model breakdown available")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                        font.italic: true
                    }

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

                    Rectangle {
                        visible: root.updateAvailable
                        Layout.fillWidth: true
                        Layout.preferredHeight: classicUpdateRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                        radius: Kirigami.Units.cornerRadius
                        color: Qt.alpha("#D97757", 0.12)

                        RowLayout {
                            id: classicUpdateRow
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing

                            PlasmaComponents.Label {
                                text: "⬆ Claude Code " + root.latestVersion + " " + i18n.tr("available")
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                font.bold: true
                                color: "#D97757"
                            }
                            Item { Layout.fillWidth: true }
                            PlasmaComponents.Button {
                                text: i18n.tr("Update")
                                icon.name: "update-none"
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                onClicked: root.launchInTerminal("claude update")
                            }
                        }
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
                            onClicked: root.refresh()
                        }
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

    readonly property int rateLimitBackoffMs: root.rateLimitRetryMs > 0
        ? root.rateLimitRetryMs + 10000
        : Math.min((root.rateLimitRetryCount + 1) * 300000, 900000)

    Timer {
        id: refreshTimer
        interval: Math.max(Plasmoid.configuration.refreshInterval || 5, 1) * 60000
        running: !root.hasRateLimitError
        repeat: true
        onTriggered: loadCredentials()
    }

    function elapsedPct(resetTime, periodMs) {
        if (!resetTime) return -1
        var remaining = resetTime.getTime() - root.nowTick
        if (remaining <= 0 || remaining > periodMs) return -1
        return Math.max(0, Math.min(100, (periodMs - remaining) / periodMs * 100))
    }

    function getUsageColor(percent, timePct) {
        if (timePct === undefined || timePct === null || timePct < 0) {
            if (percent < 50) return Kirigami.Theme.positiveTextColor
            if (percent < 80) return Kirigami.Theme.neutralTextColor
            return Kirigami.Theme.negativeTextColor
        }
        if (percent >= 100 || percent > timePct) return Kirigami.Theme.negativeTextColor
        if (percent > timePct * 0.75) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.positiveTextColor
    }

    function formatDollars(cents) {
        return "$" + (cents / 100).toFixed(2)
    }

    function checkFieldAlert(field, label, percent, timePct, thresholds) {
        var last = root.alertedThresholds[field] || 0

        if (percent < thresholds[0]) {
            if (last !== 0) {
                var updated = root.alertedThresholds
                updated[field] = 0
                root.alertedThresholds = updated
                if (last >= 95 && percent < 20) {
                    sendNotification(i18n.tr("Quota Reset"), label + ": " + i18n.tr("quota has been reset. Claude is ready to use again."))
                }
            }
            return
        }

        var crossed = 0
        for (var i = 0; i < thresholds.length; i++) {
            if (percent >= thresholds[i]) crossed = thresholds[i]
        }
        if (crossed <= last) return

        var updatedUp = root.alertedThresholds
        updatedUp[field] = crossed
        root.alertedThresholds = updatedUp

        if (root.useTimeAware && crossed < 90 && timePct >= 0 && percent <= timePct) return

        sendNotification(i18n.tr("Usage Notice"), label + " " + i18n.tr("usage has reached") + " " + Math.round(percent) + "%")
    }

    function checkAlerts() {
        checkFieldAlert("session", i18n.tr("Session (5hr)"), root.sessionUsagePercent, root.sessionTimePct, [50, 80, 95])
        checkFieldAlert("weekly", i18n.tr("Weekly (7day)"), root.weeklyUsagePercent, root.weeklyTimePct, [95])
        if (root.extraEnabled) {
            checkFieldAlert("extra", i18n.tr("Extra Usage"), root.extraPercent, -1, [50, 80, 95])
        }
    }

    function updatePlanName() {
        if (root.baseUrl) return
        var planMap = {
            "default_claude_pro": "Pro",
            "default_claude_max_5x": "Max 5x",
            "default_claude_max_20x": "Max 20x"
        }
        var tier = root.accountTier || root.credsTier
        if (planMap[tier]) {
            root.planName = planMap[tier]
        } else if (root.credsSub) {
            root.planName = root.credsSub.charAt(0).toUpperCase() + root.credsSub.slice(1)
        } else if (tier) {
            root.planName = tier.replace(/^default_/, "").replace(/_/g, " ")
                .replace(/\b\w/g, function(c) { return c.toUpperCase() })
        }
        console.log("Claude Usage: plan resolved:", root.planName, "(tier:", tier + ", sub:", root.credsSub + ")")
    }

    function modelRank(id) {
        var families = ["fable", "opus", "sonnet", "haiku"]
        var lower = id.toLowerCase()
        for (var i = 0; i < families.length; i++) {
            if (lower.indexOf(families[i]) !== -1) return i
        }
        return families.length
    }

    function modelVersion(id) {
        var m = id.toLowerCase().match(/(?:fable|opus|sonnet|haiku)[-_ ]?(\d+(?:[.-]\d+)?)/)
        return m ? parseFloat(m[1].replace("-", ".")) : 0
    }

    function sortModels(list, idField) {
        list.sort(function(a, b) {
            var ra = modelRank(a[idField]), rb = modelRank(b[idField])
            if (ra !== rb) return ra - rb
            return modelVersion(b[idField]) - modelVersion(a[idField])
        })
        return list
    }

    function prettyModelName(id) {
        var m = id.match(/(fable|opus|sonnet|haiku)[-_ ]?(\d+(?:[.-]\d+)?)?/i)
        if (!m) return id
        var family = m[1].charAt(0).toUpperCase() + m[1].slice(1).toLowerCase()
        var version = (m[2] || "").replace("-", ".")
        return version ? family + " " + version : family
    }

    function formatTokens(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
        if (n >= 1e3) return (n / 1e3).toFixed(1) + "k"
        return "" + n
    }

    function modelDisplayName(key) {
        if (key === "fable") return "Fable 5"
        if (key === "sonnet") return i18n.tr("Sonnet")
        if (key === "opus") return i18n.tr("Opus")
        return key.charAt(0).toUpperCase() + key.slice(1)
    }

    function modelBarColor(key, percent) {
        return key === "fable" ? "#D97757" : getUsageColor(percent)
    }

    function isNewerVersion(a, b) {
        var pa = a.split(".").map(Number)
        var pb = b.split(".").map(Number)
        for (var i = 0; i < 3; i++) {
            if ((pa[i] || 0) > (pb[i] || 0)) return true
            if ((pa[i] || 0) < (pb[i] || 0)) return false
        }
        return false
    }

    function checkForUpdate() {
        if (Plasmoid.configuration.enableUpdateCheck === false) return
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://registry.npmjs.org/@anthropic-ai/claude-code/latest")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    root.latestVersion = JSON.parse(xhr.responseText).version || ""
                    console.log("Claude Usage: latest version:", root.latestVersion)
                } catch (e) { /* silent */ }
            }
        }
        xhr.send()
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
        reloadQuickLinks()
        var iconSource = Qt.resolvedUrl("../icons/claude-usage-widget.svg").toString().replace("file://", "")
        iconInstaller.connectSource("bash -c 'ICON_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps && mkdir -p $ICON_DIR && cp \"" + iconSource + "\" $ICON_DIR/claude-usage-widget.svg && chmod 644 $ICON_DIR/claude-usage-widget.svg 2>/dev/null'")
        cacheReader.connectSource("cat $HOME/.local/share/claude-usage-cache.json 2>/dev/null")
        versionReader.connectSource("claude --version 2>/dev/null")
        emailReader.connectSource("cat $HOME/.claude.json 2>/dev/null")
        if (Plasmoid.configuration.enableUpdateCheck !== false) checkForUpdate()
        refreshTokenStats()
        loadCredentials()
        updateProcessVisibility()
    }

    // Only use custom background on desktop, panel keeps default Plasma background
    readonly property bool isOnPanel: Plasmoid.location === PlasmaCore.Types.TopEdge
        || Plasmoid.location === PlasmaCore.Types.BottomEdge
        || Plasmoid.location === PlasmaCore.Types.LeftEdge
        || Plasmoid.location === PlasmaCore.Types.RightEdge

    readonly property bool useCustomBackground: !isOnPanel && Plasmoid.configuration.backgroundOpacity < 1.0

    Plasmoid.backgroundHints: root.useCustomBackground ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground

    Rectangle {
        visible: root.useCustomBackground
        anchors.fill: parent
        color: "transparent"
        radius: Kirigami.Units.cornerRadius
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        border.width: 1

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Kirigami.Theme.backgroundColor
            opacity: Plasmoid.configuration.backgroundOpacity
        }
    }

    Plasmoid.icon: "claude-usage-widget"
    toolTipMainText: i18n.tr("Claude Usage")
    toolTipSubText: {
        var parts = []
        if (Plasmoid.configuration.showSession !== false)
            parts.push(i18n.tr("Session (5hr)") + ": " + Math.round(root.sessionUsagePercent) + "%")
        if (Plasmoid.configuration.showWeekly !== false)
            parts.push(i18n.tr("Weekly (7day)") + ": " + Math.round(root.weeklyUsagePercent) + "%")
        for (var i = 0; i < root.modelLimits.length; i++) {
            if (root.isModelShownInPanel(root.modelLimits[i].label))
                parts.push(root.modelLimits[i].label + ": " + Math.round(root.modelLimits[i].percent) + "%")
        }
        return parts.join(" | ")
    }
}
