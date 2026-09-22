import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "GuardModel.js" as GuardModel

Panel {
    id: root
    // The manifest supplies the custom plugin ID.
    property var manifest: null
    readonly property string pluginId: manifest && manifest.id
        ? String(manifest.id) : "roubilibo.oled-guard"

    moduleName: root.pluginId
    ipcTarget: root.pluginId
    manageIpc: false

    readonly property var service: {
        try {
            if (bar && bar.shell && typeof bar.shell.serviceFor === "function")
                return bar.shell.serviceFor(root.pluginId)
        } catch (e) {
            return null
        }
        return null
    }

    // Prefer the live service snapshot over the injected bar settings.
    function guardSetting(name, fallback) {
        var live = service ? service.config : null
        if (live && live[name] !== undefined && live[name] !== null)
            return live[name]
        return setting(name, fallback)
    }

    readonly property bool guardEnabled: guardSetting("enabled", true) !== false
    readonly property bool guardChecker: guardSetting("checkerboard", false) === true
    readonly property bool guardPaused: service ? !!service.paused : false
    readonly property bool guardActive: service ? !!service.active : false

    readonly property string glyphGuarding: String.fromCodePoint(0xF0780) // shield-half-full
    readonly property string glyphStandby: String.fromCodePoint(0xF099D) // shield-outline
    readonly property string glyphOff: String.fromCodePoint(0xF099E) // shield-off-outline

    readonly property string glyph: {
        if (!service || guardPaused || !guardEnabled)
            return glyphOff
        return guardActive ? glyphGuarding : glyphStandby
    }

    readonly property string levelValue: guardEnabled ? depthValue : "off"
    readonly property string powerValue: guardEnabled ? "on" : "off"
    readonly property string lookValue: guardChecker ? "checker" : "flat"
    readonly property bool guardReveal: guardSetting("revealOnHover", false) === true
    readonly property string revealValue: guardReveal ? "hover" : "always"

    readonly property var defaultDepths: ({
        light: { baseOpacity: 0.10, idleOpacity: 0.40 },
        medium: { baseOpacity: 0.15, idleOpacity: 0.55 },
        deep: { baseOpacity: 0.25, idleOpacity: 0.75 },
        veiled: { baseOpacity: 0.85, idleOpacity: 0.90 }
    })
    readonly property var depths: guardSetting("levels", defaultDepths)

    function levelPreset(name) {
        return depths && depths[name] ? depths[name] : defaultDepths[name]
    }

    function percent(value) {
        return Math.round(Number(value) * 100) + "%"
    }

    function levelTooltip(name) {
        var preset = levelPreset(name)
        if (!preset)
            return name
        var text = percent(preset.baseOpacity) + " working, "
            + percent(preset.idleOpacity) + " idle"
        return name === "veiled" ? text + ". Needs Reveal on hover to stay usable." : text
    }

    readonly property string depthValue: {
        var configured = String(guardSetting("level", ""))
        if (levelPreset(configured))
            return configured
        var base = Number(guardSetting("baseOpacity", 0.15))
        if (base <= 0.12)
            return "light"
        if (base <= 0.20)
            return "medium"
        if (base <= 0.50)
            return "deep"
        return "veiled"
    }

    readonly property string activeLevelTooltip: levelTooltip(depthValue)

    readonly property string stateLine: {
        if (!service)
            return "service not running"
        if (guardPaused)
            return "paused"
        if (!guardEnabled)
            return "off"
        if (!service.lit)
            return "panel not lit"
        if (service.fullscreen)
            return "standing by — fullscreen"
        if (guardActive)
            return "attenuating " + Math.round(service.attenuation * 100) + "%"
        return "standing by"
    }

    // Persist and apply one complete settings snapshot.
    function applySettings(patch) {
        var entry = { id: root.moduleName }
        for (var key in root.settings)
            if (key !== "id")
                entry[key] = root.settings[key]
        if (root.service && root.service.config) {
            for (var liveKey in root.service.config)
                entry[liveKey] = root.service.config[liveKey]
        }
        for (var k in patch)
            entry[k] = patch[k]

        var persisted = false
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
            persisted = root.bar.shell.updateEntryInline(root.moduleName, entry)
        root.settings = entry
        if (root.service && typeof root.service.applyConfig === "function")
            root.service.applyConfig(entry)
        return persisted
    }

    function setPower(value) {
        if (value === "off") {
            applySettings({ enabled: false })
            return
        }
        applySettings({ enabled: true })
        if (root.service)
            root.service.paused = false
    }

    function setLevel(value) {
        if (value === "off") {
            applySettings({ enabled: false })
            return
        }
        var preset = root.levelPreset(value)
        if (!preset)
            return
        applySettings({
            enabled: true,
            level: value,
            baseOpacity: preset.baseOpacity,
            idleOpacity: preset.idleOpacity
        })
        if (root.service)
            root.service.paused = false
    }

    function setLook(value) {
        applySettings({ checkerboard: value === "checker" })
    }

    function setReveal(value) {
        applySettings({ revealOnHover: value === "hover" })
    }

    function setMode(value) {
        if (value === "off") {
            setPower("off")
            return
        }
        applySettings({ enabled: true, checkerboard: value === "checker" })
        if (root.service)
            root.service.paused = false
    }

    function setDepth(value) {
        var preset = root.levelPreset(value)
        if (preset)
            applySettings({
                level: value,
                baseOpacity: preset.baseOpacity,
                idleOpacity: preset.idleOpacity
            })
    }

    IpcHandler {
        target: root.ipcTarget

        function open(): void { root.open() }
        function close(): void { root.close() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
        function toggle(): void { root.toggle() }

        function mode(value: string): string {
            var v = String(value || "")
            if (v !== "off" && v !== "dim" && v !== "checker")
                return "expected off|dim|checker"
            root.setMode(v)
            return v
        }

        function depth(value: string): string {
            var v = String(value || "")
            if (!root.levelPreset(v))
                return "expected light|medium|deep"
            root.setDepth(v)
            return v
        }

        function level(value: string): string {
            var v = String(value || "")
            if (v !== "off" && !root.levelPreset(v))
                return "expected off|light|medium|deep|veiled"
            root.setLevel(v)
            return v
        }

        function reveal(value: string): string {
            var v = String(value || "")
            if (v !== "always" && v !== "hover")
                return "expected always|hover"
            root.setReveal(v)
            return v
        }

        function look(value: string): string {
            var v = String(value || "")
            if (v !== "flat" && v !== "checker")
                return "expected flat|checker"
            root.setLook(v)
            return v
        }

        function state(): string {
            return JSON.stringify({
                level: root.levelValue,
                power: root.powerValue,
                look: root.lookValue,
                reveal: root.revealValue,
                depth: root.depthValue,
                opened: root.opened
            })
        }
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.glyph
        tooltipText: "OLED Guard# — " + root.stateLine + " (" + root.activeLevelTooltip + ")"
        onPressed: function (b) {
            if (b === Qt.RightButton && root.service)
                root.service.paused = !root.service.paused
            else
                root.toggle()
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(330))
        contentHeight: panel.fittedContentHeight(column.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function (direction) { root.switchPanel(direction) }

            Column {
                id: column
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Style.space(12)

                Row {
                    spacing: Style.space(10)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.glyph
                        color: root.bar ? root.bar.foreground : Color.foreground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.displayLarge
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)

                        Text {
                            text: "OLED Guard#"
                            color: root.bar ? root.bar.foreground : Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            font.bold: true
                        }

                        Text {
                            text: root.stateLine
                            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                    }
                }

                PanelSeparator { width: parent.width }

                PanelSectionHeader { text: "LEVEL" }

                ButtonGroup {
                    width: parent.width
                    value: root.levelValue
                    options: [
                        { value: "off", label: "Off", tooltip: "No attenuation" },
                        { value: "light", label: "Light", tooltip: root.levelTooltip("light") },
                        { value: "medium", label: "Med", tooltip: root.levelTooltip("medium") },
                        { value: "deep", label: "Deep", tooltip: root.levelTooltip("deep") },
                        { value: "veiled", label: "Veil", tooltip: root.levelTooltip("veiled") }
                    ]
                    onChanged: function (value) { root.setLevel(value) }
                }

                PanelSectionHeader { text: "REVEAL" }

                ButtonGroup {
                    width: parent.width
                    enabled: root.guardEnabled
                    opacity: root.guardEnabled ? 1 : 0.4
                    value: root.revealValue
                    options: [
                        { value: "always", label: "Always on", tooltip: "Veil holds at the chosen level at all times" },
                        { value: "hover", label: "On hover", tooltip: "Veil clears the moment the pointer reaches the bar" }
                    ]
                    onChanged: function (value) { root.setReveal(value) }
                }

                PanelSectionHeader { text: "LOOK" }

                ButtonGroup {
                    width: parent.width
                    enabled: root.guardEnabled
                    opacity: root.guardEnabled ? 1 : 0.4
                    value: root.lookValue
                    options: [
                        { value: "flat", label: "Flat", tooltip: "Even attenuation. Protects best at every level." },
                        { value: "checker", label: "Checker", tooltip: "Textured. Same average, slightly worse for wear \u2014 a look, not more protection." }
                    ]
                    onChanged: function (value) { root.setLook(value) }
                }

            }
        }
    }
}
