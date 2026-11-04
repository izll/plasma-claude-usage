/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    property string cfg_language
    property string cfg_credentialsPath
    property bool cfg_autoRefreshSession
    property string cfg_baseUrl
    property string cfg_apiKey
    property string cfg_proxyUrl

    // Translation helper
    Translations {
        id: trans
        currentLanguage: cfg_language || "system"
    }

    function tr(text) { return trans.tr(text); }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Authentication")
        }

        QQC2.TextField {
            id: credentialsPathField
            Kirigami.FormData.label: tr("Credentials path:")
            placeholderText: "~/.claude/.credentials.json"
            text: cfg_credentialsPath
            onTextChanged: cfg_credentialsPath = text
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: tr("Full path to .credentials.json, or the folder containing it. The same folder is used for account info and token stats. Leave empty to use $CLAUDE_CONFIG_DIR, or ~/.claude when it is not set.")
            font.italic: true
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Session refresh:")
            text: tr("Automatically refresh expired session")
            checked: cfg_autoRefreshSession
            onToggled: cfg_autoRefreshSession = checked
        }

        QQC2.Label {
            text: tr("Briefly reopens claude in the background (about 15 seconds, no visible window, no message sent) to refresh the session before prompting you to log in manually.")
            font.italic: true
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
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
            text: tr("Leave empty to use the credentials file (default)")
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

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Network")
        }

        QQC2.TextField {
            id: proxyField
            Kirigami.FormData.label: tr("Proxy:")
            placeholderText: "socks5h://127.0.0.1:1080"
            text: cfg_proxyUrl
            onTextChanged: cfg_proxyUrl = text
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: tr("Proxy for the widget's own requests (usage, service status, update checks), e.g. socks5h://127.0.0.1:1080 or http://proxy:8080. Leave empty to connect directly (curl still honours HTTPS_PROXY and ALL_PROXY). Not used with a custom base URL.")
            font.italic: true
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
    }
}
