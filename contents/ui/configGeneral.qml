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
    property int cfg_refreshInterval
    property string cfg_baseUrl
    property string cfg_apiKey

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
