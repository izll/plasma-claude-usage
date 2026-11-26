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
    property string cfg_panelStyle
    property bool cfg_showSession
    property bool cfg_showWeekly
    property string cfg_showModelLimits
    property string cfg_panelLayout
    property int cfg_metricsScale
    property int cfg_panelMargin
    property string cfg_ringCenter
    property int cfg_ringLogoSize
    property bool cfg_showWindowLabels
    property bool cfg_showIcon
    property string cfg_panelIcon
    property int cfg_iconSize

    property string cfg_knownModels
    readonly property var availableModels: (cfg_knownModels || "").split(",").filter(function(n) { return n !== "" })

    readonly property bool ringStyle: (cfg_panelStyle || "ring") === "ring"
    readonly property bool logoInRing: ringStyle && (cfg_ringCenter || "percent").indexOf("logo") === 0

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

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Panel display")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Style:")
            model: [tr("Ring"), tr("Text"), tr("Bar")]
            currentIndex: cfg_panelStyle === "text" ? 1 : cfg_panelStyle === "bar" ? 2 : 0
            onActivated: function(index) {
                var styles = ["ring", "text", "bar"]
                cfg_panelStyle = styles[index]
            }
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

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Layout:")
            model: [tr("Horizontal"), tr("Vertical")]
            currentIndex: cfg_panelLayout === "vertical" ? 1 : 0
            onActivated: function(index) { cfg_panelLayout = index === 1 ? "vertical" : "horizontal" }
        }

        RowLayout {
            Kirigami.FormData.label: tr("Metrics size (panel and popup):")

            QQC2.Slider {
                id: metricsScaleSlider
                from: 100
                to: 300
                stepSize: 10
                snapMode: QQC2.Slider.SnapAlways
                value: cfg_metricsScale
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10

                // Not onMoved: that signal fires only while dragging the handle,
                // so scrolling the wheel or using the arrow keys would move the
                // slider without ever marking the page dirty.
                onValueChanged: {
                    if (cfg_metricsScale !== value) {
                        cfg_metricsScale = value
                    }
                }
            }

            QQC2.Label {
                text: Math.round(cfg_metricsScale) + "%"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: tr("Panel margin:")
            QQC2.SpinBox {
                from: 0
                to: 32
                value: cfg_panelMargin
                onValueChanged: cfg_panelMargin = value
                textFromValue: function(value) { return value + "px" }
                valueFromText: function(text) { return parseInt(text) || 0 }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Ring")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Ring center:")
            enabled: configPage.ringStyle
            model: [tr("Percent"), tr("Logo"), tr("Logo + %")]
            currentIndex: cfg_ringCenter === "logo" ? 1 : cfg_ringCenter === "logo_percent" ? 2 : 0
            onActivated: function(index) { cfg_ringCenter = ["percent", "logo", "logo_percent"][index] }
        }

        RowLayout {
            Kirigami.FormData.label: tr("Ring logo size:")
            enabled: configPage.logoInRing

            QQC2.Slider {
                from: 50
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways
                value: cfg_ringLogoSize
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10

                onValueChanged: {
                    if (cfg_ringLogoSize !== value) {
                        cfg_ringLogoSize = value
                    }
                }
            }

            QQC2.Label {
                text: Math.round(cfg_ringLogoSize) + "%"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Window labels:")
            enabled: configPage.ringStyle
            text: tr("Show 5h/7d on rings")
            checked: cfg_showWindowLabels
            onCheckedChanged: cfg_showWindowLabels = checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Icon")
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
            onActivated: function(index) { cfg_panelIcon = index === 1 ? "tile" : "claude" }
            // also picks the logo shown inside the rings in the logo modes
            enabled: cfg_showIcon || configPage.logoInRing
        }

        RowLayout {
            Kirigami.FormData.label: tr("Icon size:")
            enabled: cfg_showIcon

            QQC2.Slider {
                id: iconSizeSlider
                from: 0
                to: 64
                stepSize: 2
                snapMode: QQC2.Slider.SnapAlways
                value: cfg_iconSize
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10

                onValueChanged: {
                    if (cfg_iconSize !== value) {
                        cfg_iconSize = value
                    }
                }
            }

            QQC2.Label {
                text: cfg_iconSize === 0 ? tr("Auto") : cfg_iconSize + "px"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }
    }
}
