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

KCM.SimpleKCM {
    id: configPage

    property string cfg_language
    property int cfg_refreshInterval
    property bool cfg_enableNotifications
    property bool cfg_enableUpdateCheck
    property bool cfg_checkWidgetUpdates
    property bool cfg_enableStatusCheck
    property bool cfg_useTimeAwareColors
    property string cfg_processVisibility
    property int cfg_processCheckInterval

    // Widget version: the installed one from the package's metadata.json,
    // the latest one from the KDE Store (only when update checks are on).
    readonly property string storeProductId: "2331316"
    property string installedVersion: ""
    property string storeVersion: ""
    readonly property bool widgetUpdateAvailable: installedVersion !== "" && storeVersion !== ""
        && isNewerVersion(storeVersion, installedVersion)

    function isNewerVersion(a, b) {
        var pa = a.split(".").map(Number)
        var pb = b.split(".").map(Number)
        for (var i = 0; i < 3; i++) {
            if ((pa[i] || 0) > (pb[i] || 0)) return true
            if ((pa[i] || 0) < (pb[i] || 0)) return false
        }
        return false
    }

    Plasma5Support.DataSource {
        id: versionSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = data["stdout"] || ""
            disconnectSource(sourceName)
            if (sourceName.indexOf("cat ") === 0) {
                try { configPage.installedVersion = JSON.parse(stdout).KPlugin.Version || "" } catch (e) {}
            } else if (sourceName.indexOf("curl ") === 0) {
                var m = stdout.match(/<content[^>]*>[\s\S]*?<version>([^<]+)<\/version>/)
                if (m) configPage.storeVersion = m[1].trim()
            }
        }
    }

    function checkStoreVersion() {
        if (cfg_checkWidgetUpdates)
            versionSource.connectSource("curl -sS --max-time 10 https://api.kde-look.org/ocs/v1/content/data/" + storeProductId + " 2>/dev/null")
    }

    function openWidgetUpdates() {
        versionSource.connectSource("sh -c 'if command -v knewstuff-dialog6 >/dev/null; then setsid knewstuff-dialog6 plasmoids.knsrc; "
            + "elif command -v plasma-discover >/dev/null; then setsid plasma-discover --mode update; "
            + "else xdg-open https://store.kde.org/p/" + storeProductId + "; fi >/dev/null 2>&1 &'")
    }

    Component.onCompleted: {
        var metadata = decodeURIComponent(Qt.resolvedUrl("../../metadata.json").toString().replace("file://", ""))
        versionSource.connectSource("cat '" + metadata + "'")
        checkStoreVersion()
    }

    onCfg_checkWidgetUpdatesChanged: if (cfg_checkWidgetUpdates && storeVersion === "") checkStoreVersion()

    // Translation helper
    Translations {
        id: trans
        currentLanguage: cfg_language || "system"
    }

    function tr(text) { return trans.tr(text); }

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

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Notifications:")
            text: tr("Threshold and reset notifications")
            checked: cfg_enableNotifications
            onCheckedChanged: cfg_enableNotifications = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Update check") + ":"
            text: tr("Check for Claude Code updates")
            checked: cfg_enableUpdateCheck
            onCheckedChanged: cfg_enableUpdateCheck = checked
        }

        QQC2.CheckBox {
            text: tr("Check for widget updates")
            checked: cfg_checkWidgetUpdates
            onCheckedChanged: cfg_checkWidgetUpdates = checked
        }

        RowLayout {
            Kirigami.FormData.label: tr("Widget version:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: configPage.installedVersion || "…"
            }

            QQC2.Label {
                visible: cfg_checkWidgetUpdates && configPage.storeVersion !== "" && !configPage.widgetUpdateAvailable
                text: "✓ " + tr("Up to date")
                opacity: 0.7
            }

            QQC2.Label {
                visible: configPage.widgetUpdateAvailable
                text: "⬆ " + configPage.storeVersion + " " + tr("available")
                font.bold: true
            }

            QQC2.Button {
                visible: configPage.widgetUpdateAvailable
                text: tr("Update")
                icon.name: "update-none"
                onClicked: configPage.openWidgetUpdates()
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Service status:")
            text: tr("Check status.claude.com")
            checked: cfg_enableStatusCheck
            onCheckedChanged: cfg_enableStatusCheck = checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Colors")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Colors:")
            text: tr("Time-proportional warnings")
            checked: cfg_useTimeAwareColors
            onCheckedChanged: cfg_useTimeAwareColors = checked
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
    }
}
