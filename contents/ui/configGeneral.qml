/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    id: configPage

    property string cfg_language
    property int cfg_refreshInterval
    property string cfg_panelLayout
    property bool cfg_showIcon
    property string cfg_panelStyle
    property bool cfg_showSession
    property bool cfg_showWeekly
    property string cfg_showModelLimits
    property string cfg_quickLinks
    property string cfg_processVisibility
    property int cfg_processCheckInterval
    property string cfg_popupStyle
    property string cfg_panelIcon
    property bool cfg_enableNotifications
    property bool cfg_enableUpdateCheck
    property bool cfg_showInstallations
    property string cfg_cardOrder
    property string cfg_baseUrl
    property string cfg_apiKey
    property double cfg_backgroundOpacity
    property bool cfg_useTimeAwareColors
    property bool cfg_scrollableContent

    property var availableModels: []
    property var quickLinksModel: []
    property var cardOrderModel: []

    readonly property var defaultCardOrder: [
        {id: "account", enabled: true},
        {id: "usage", enabled: true},
        {id: "models", enabled: true},
        {id: "extra", enabled: true},
        {id: "tokens", enabled: true},
        {id: "trend", enabled: true},
        {id: "installations", enabled: true},
        {id: "links", enabled: true}
    ]

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

    function cardDisplayName(cardId) {
        return tr(cardNames[cardId] || cardId)
    }

    onCfg_cardOrderChanged: {
        try { cardOrderModel = JSON.parse(cfg_cardOrder || "[]") }
        catch (e) { cardOrderModel = defaultCardOrder.slice() }
        if (cardOrderModel.length === 0) cardOrderModel = defaultCardOrder.slice()
    }

    function saveCardOrder() {
        cfg_cardOrder = JSON.stringify(cardOrderModel)
    }

    function moveCard(index, direction) {
        var list = cardOrderModel.slice()
        var target = index + direction
        if (target < 0 || target >= list.length) return
        var tmp = list[index]
        list[index] = list[target]
        list[target] = tmp
        cardOrderModel = list
        saveCardOrder()
    }

    function toggleCard(index) {
        var list = cardOrderModel.slice()
        var item = Object.assign({}, list[index])
        item.enabled = !item.enabled
        list[index] = item
        cardOrderModel = list
        saveCardOrder()
    }

    onCfg_quickLinksChanged: {
        try { quickLinksModel = JSON.parse(cfg_quickLinks || "[]") }
        catch (e) { quickLinksModel = [] }
    }

    // Translation helper
    Translations {
        id: trans
        currentLanguage: cfg_language || "system"
    }

    function tr(text) { return trans.tr(text); }

    function isModelEnabled(name) {
        var list = (cfg_showModelLimits || "").toString().split(",").filter(function(s) { return s.trim() !== "" })
        return list.indexOf(name) >= 0
    }

    function setModelEnabled(name, enabled) {
        var list = (cfg_showModelLimits || "").toString().split(",").filter(function(s) { return s.trim() !== "" })
        var idx = list.indexOf(name)
        if (enabled && idx < 0) list.push(name)
        else if (!enabled && idx >= 0) list.splice(idx, 1)
        cfg_showModelLimits = list.join(",")
    }

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
                    var models = cache.modelLimits || []
                    var names = []
                    for (var i = 0; i < models.length; i++) {
                        if (models[i].name) names.push(models[i].name)
                    }
                    if (names.length > 0) configPage.availableModels = names
                } catch (e) {
                    console.log("Config: Cache parse error:", e)
                }
            }
        }
    }

    function updateQuickLink(index, field, value) {
        var links = quickLinksModel.slice()
        if (index >= 0 && index < links.length) {
            var link = Object.assign({}, links[index])
            link[field] = value
            links[index] = link
            cfg_quickLinks = JSON.stringify(links)
        }
    }

    function removeQuickLink(index) {
        var links = quickLinksModel.slice()
        links.splice(index, 1)
        cfg_quickLinks = JSON.stringify(links)
    }

    function addQuickLink() {
        var links = quickLinksModel.slice()
        links.push({name: "", url: "", icon: "internet-web-browser"})
        cfg_quickLinks = JSON.stringify(links)
    }

    property int iconEditIndex: -1

    readonly property var defaultQuickLinks: [
        {name: "Claude", url: "https://claude.ai", icon: "internet-web-browser"},
        {name: "Usage", url: "https://claude.ai/#settings/usage", icon: "office-chart-bar"},
        {name: "Console", url: "https://platform.claude.com/", icon: "utilities-terminal"}
    ]

    Component.onCompleted: {
        cacheReader.connectSource("cat $HOME/.local/share/claude-usage-cache.json 2>/dev/null")
        try { quickLinksModel = JSON.parse(cfg_quickLinks || "[]") }
        catch (e) { quickLinksModel = [] }
        try { cardOrderModel = JSON.parse(cfg_cardOrder || "[]") }
        catch (e) { cardOrderModel = defaultCardOrder.slice() }
        if (cardOrderModel.length === 0) cardOrderModel = defaultCardOrder.slice()
    }

    readonly property var languageValues: [
        "system", "en_US", "hu_HU", "de_DE", "fr_FR", "es_ES",
        "it_IT", "pt_BR", "ru_RU", "pl_PL", "nl_NL", "tr_TR",
        "ja_JP", "ko_KR", "zh_CN", "zh_TW"
    ]

    readonly property var languageNames: [
        tr("System default"), "English", "Magyar", "Deutsch",
        "Français", "Español", "Italiano", "Português (Brasil)",
        "Русский", "Polski", "Nederlands", "Türkçe",
        "日本語", "한국어", "简体中文", "繁體中文"
    ]

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: languageCombo
            Kirigami.FormData.label: tr("Language:")

            model: languageNames
            currentIndex: languageValues.indexOf(cfg_language)

            onActivated: index => {
                cfg_language = languageValues[index]
            }
        }

        RowLayout {
            Kirigami.FormData.label: tr("Refresh interval:")

            QQC2.SpinBox {
                id: refreshSpinBox
                from: 1
                to: 999
                stepSize: 1
                value: cfg_refreshInterval

                onValueChanged: {
                    cfg_refreshInterval = value
                }
            }

            QQC2.Label {
                text: tr("minutes")
            }
        }

        QQC2.Label {
            visible: cfg_refreshInterval < 5
            text: "⚠ " + tr("Values under 5 min may cause rate limiting")
            color: Kirigami.Theme.negativeTextColor
            font.italic: true
            Layout.fillWidth: true
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Popup style:")
            model: [tr("Classic"), tr("Card")]
            currentIndex: cfg_popupStyle === "classic" ? 0 : 1
            onCurrentIndexChanged: cfg_popupStyle = currentIndex === 0 ? "classic" : "card"
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Scrollable content:")
            text: tr("Enable scrollable content")
            checked: cfg_scrollableContent
            onToggled: cfg_scrollableContent = checked
            visible: cfg_popupStyle !== "classic"
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Popup cards")
            visible: cfg_popupStyle !== "classic"
        }

        ColumnLayout {
            Kirigami.FormData.label: ""
            visible: cfg_popupStyle !== "classic"
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: configPage.cardOrderModel
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.CheckBox {
                        checked: modelData.enabled !== false
                        onClicked: configPage.toggleCard(index)
                    }

                    QQC2.Label {
                        text: configPage.cardDisplayName(modelData.id)
                        Layout.fillWidth: true
                        opacity: modelData.enabled !== false ? 1.0 : 0.5
                    }

                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: index > 0
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: configPage.moveCard(index, -1)
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    }

                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: index < configPage.cardOrderModel.length - 1
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: configPage.moveCard(index, 1)
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    }
                }
            }

            QQC2.Button {
                text: tr("Reset to default")
                icon.name: "edit-undo"
                onClicked: {
                    configPage.cardOrderModel = configPage.defaultCardOrder.slice()
                    configPage.saveCardOrder()
                }
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Notifications:")
            text: tr("Threshold and reset notifications")
            checked: cfg_enableNotifications
            onCheckedChanged: cfg_enableNotifications = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Update check")
            text: tr("Check for Claude Code updates")
            checked: cfg_enableUpdateCheck
            onCheckedChanged: cfg_enableUpdateCheck = checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Panel display")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Layout:")
            model: [tr("Horizontal"), tr("Vertical")]
            currentIndex: cfg_panelLayout === "vertical" ? 1 : 0
            onCurrentIndexChanged: cfg_panelLayout = currentIndex === 1 ? "vertical" : "horizontal"
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Icon:")
            text: tr("Show Claude icon")
            checked: cfg_showIcon
            onCheckedChanged: cfg_showIcon = checked
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Panel icon:")
            model: ["Claude", "Tile"]
            currentIndex: (cfg_panelIcon || "claude") === "tile" ? 1 : 0
            onCurrentIndexChanged: cfg_panelIcon = currentIndex === 1 ? "tile" : "claude"
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Style:")
            model: [tr("Ring"), tr("Text"), tr("Bar")]
            currentIndex: cfg_panelStyle === "text" ? 1 : cfg_panelStyle === "bar" ? 2 : 0
            onCurrentIndexChanged: {
                var styles = ["ring", "text", "bar"]
                cfg_panelStyle = styles[currentIndex]
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Colors:")
            text: tr("Time-proportional warnings")
            checked: cfg_useTimeAwareColors
            onCheckedChanged: cfg_useTimeAwareColors = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Show in panel:")
            text: tr("Session (5hr)")
            checked: cfg_showSession
            onCheckedChanged: cfg_showSession = checked
        }

        QQC2.CheckBox {
            text: tr("Weekly (7day)")
            checked: cfg_showWeekly
            onCheckedChanged: cfg_showWeekly = checked
        }

        // Dynamic model checkboxes from cached API data
        Repeater {
            id: modelRepeater
            model: configPage.availableModels
            delegate: QQC2.CheckBox {
                text: modelData
                checked: configPage.isModelEnabled(modelData)
                onCheckedChanged: configPage.setModelEnabled(modelData, checked)
            }
        }

        QQC2.Label {
            visible: configPage.availableModels.length === 0
            text: tr("No model data yet")
            font.italic: true
            opacity: 0.6
        }

        RowLayout {
            Kirigami.FormData.label: tr("Background opacity (desktop):")

            QQC2.Slider {
                id: opacitySlider
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: cfg_backgroundOpacity
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10

                onMoved: {
                    cfg_backgroundOpacity = value
                }
            }

            QQC2.Label {
                text: opacitySlider.value >= 1.0 ? tr("Theme") : Math.round(opacitySlider.value * 100) + "%"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Quick links")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Quick links") + ":"
            text: tr("Show quick links in popup")
            checked: configPage.quickLinksModel.length > 0
            onClicked: {
                if (checked) {
                    cfg_quickLinks = JSON.stringify(configPage.defaultQuickLinks)
                } else {
                    cfg_quickLinks = "[]"
                }
            }
        }

        ColumnLayout {
            visible: configPage.quickLinksModel.length > 0
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: configPage.quickLinksModel
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        icon.name: modelData.icon || "internet-web-browser"
                        display: QQC2.AbstractButton.IconOnly
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                        onClicked: {
                            configPage.iconEditIndex = index
                            iconDialog.open()
                        }
                        QQC2.ToolTip.text: modelData.icon || ""
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.TextField {
                        text: modelData.name || ""
                        placeholderText: tr("Name")
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        onTextChanged: configPage.updateQuickLink(index, "name", text)
                    }

                    QQC2.TextField {
                        text: modelData.url || ""
                        placeholderText: "https://..."
                        Layout.fillWidth: true
                        onTextChanged: configPage.updateQuickLink(index, "url", text)
                    }

                    QQC2.Button {
                        icon.name: "edit-delete"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: configPage.removeQuickLink(index)
                    }
                }
            }

            QQC2.Button {
                icon.name: "list-add"
                text: tr("Add link")
                onClicked: configPage.addQuickLink()
            }
        }

        KIconThemes.IconDialog {
            id: iconDialog
            onIconNameChanged: {
                if (iconName && configPage.iconEditIndex >= 0) {
                    configPage.updateQuickLink(configPage.iconEditIndex, "icon", iconName)
                    configPage.iconEditIndex = -1
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Visibility")
        }

        QQC2.ComboBox {
            id: processVisibilityCombo
            Kirigami.FormData.label: tr("When Claude is not running:")
            model: [tr("Always show full widget"), tr("Hide usage, only show icon"), tr("Fully hide widget")]
            currentIndex: cfg_processVisibility === "hide_usage" ? 1 : cfg_processVisibility === "fully_hidden" ? 2 : 0
            onCurrentIndexChanged: {
                var values = ["always", "hide_usage", "fully_hidden"]
                cfg_processVisibility = values[currentIndex]
            }
        }

        RowLayout {
            Kirigami.FormData.label: tr("Process check interval:")
            enabled: processVisibilityCombo.currentIndex > 0

            QQC2.SpinBox {
                id: processCheckSpinBox
                from: 5
                to: 300
                stepSize: 5
                value: cfg_processCheckInterval

                onValueChanged: {
                    cfg_processCheckInterval = value
                }
            }

            QQC2.Label {
                text: tr("seconds")
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Custom API (optional)")
        }

        QQC2.TextField {
            id: baseUrlField
            Kirigami.FormData.label: tr("Base URL:")
            placeholderText: "https://api.anthropic.com"
            text: cfg_baseUrl
            onTextChanged: cfg_baseUrl = text
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: tr("Leave empty to use ~/.claude/.credentials.json (default)")
            font.italic: true
            opacity: 0.7
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: apiKeyField
            Kirigami.FormData.label: tr("API key:")
            placeholderText: "sk-ant-..."
            text: cfg_apiKey
            echoMode: TextInput.Password
            enabled: cfg_baseUrl !== ""
            onTextChanged: cfg_apiKey = text
            Layout.fillWidth: true
        }
    }
}
