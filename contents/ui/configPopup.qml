/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    id: configPage

    property string cfg_language
    property string cfg_popupStyle
    property bool cfg_scrollableContent
    property double cfg_backgroundOpacity
    property string cfg_cardOrder
    property string cfg_quickLinks

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
        try { quickLinksModel = JSON.parse(cfg_quickLinks || "[]") }
        catch (e) { quickLinksModel = [] }
        try { cardOrderModel = JSON.parse(cfg_cardOrder || "[]") }
        catch (e) { cardOrderModel = defaultCardOrder.slice() }
        if (cardOrderModel.length === 0) cardOrderModel = defaultCardOrder.slice()
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Widget style:")
            model: [tr("Classic"), tr("Card")]
            currentIndex: cfg_popupStyle === "classic" ? 0 : 1
            onActivated: function(index) { cfg_popupStyle = index === 0 ? "classic" : "card" }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Scrollable content:")
            text: tr("Enable scrollable content")
            checked: cfg_scrollableContent
            onToggled: cfg_scrollableContent = checked
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
            Kirigami.FormData.label: tr("Sections")
        }

        ColumnLayout {
            Kirigami.FormData.label: ""
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
    }
}
