import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "GuardModel.js" as GuardModel

Item {
    id: root

    // Injected by omarchy-shell's service loader.
    property var shell: null
    property string omarchyPath: ""
    property var manifest: null

    // Third-party plugins receive the bar configuration through barConfig.
    readonly property string pluginId: manifest && manifest.id
        ? String(manifest.id) : GuardModel.PLUGIN_ID
    property var config: GuardModel.normalize({})
    readonly property var safeConfig: root.config || GuardModel.normalize({})

    function configFromHost() {
        return GuardModel.normalize(
            GuardModel.entryFor(shell ? { bar: shell.barConfig } : null, root.pluginId))
    }

    function syncConfigFromHost() {
        root.config = root.configFromHost()
    }

    // Read and normalize one complete JSON entry.
    function syncConfigFromJson(raw) {
        var parsed = null
        try {
            parsed = JSON.parse(String(raw || ""))
        } catch (e) {
            return
        }
        var entry = GuardModel.entryFor(parsed, root.pluginId)
        if (entry)
            root.applyConfig(entry)
    }

    function applyConfig(entry) {
        root.config = GuardModel.normalize(entry || {})
    }

    onShellChanged: root.syncConfigFromHost()
    onManifestChanged: root.syncConfigFromHost()

    FileView {
        id: userConfigFile
        path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.syncConfigFromJson(text())
        onFileChanged: reload()
    }

    property bool paused: false

    property bool idle: false
    property int phase: 0

    property int hyprRevision: 0

    readonly property bool locked: {
        try {
            var lock = shell && typeof shell.serviceFor === "function"
                ? shell.serviceFor("omarchy.lock") : null
            return lock ? !!lock.locked : false
        } catch (e) {
            return false
        }
    }
    readonly property bool lit: !locked

    readonly property var barConfig: shell ? shell.barConfig : null
    readonly property string edge: GuardModel.edgeFor(barConfig)
    readonly property int barThickness: shell && shell.bar && shell.bar.barSize > 0 ? shell.bar.barSize : 26
    readonly property bool barHidden: shell && shell.bar ? !!shell.bar.barHidden : false

    // The scoped bar API has no hover state; use the global cursor position.
    property bool pointerOnBar: false
    readonly property bool barHovered: pointerOnBar

    function cursorOnBar(x, y) {
        var screens = Quickshell.screens
        var thickness = Math.max(0, Number(root.barThickness))
        var edge = root.edge
        for (var i = 0; i < screens.length; i++) {
            var screen = screens[i]
            var monitor = null
            try { monitor = Hyprland.monitorFor(screen) } catch (e) {}
            if (!monitor)
                continue

            var mx = Number(monitor.x)
            var my = Number(monitor.y)
            var mw = Number(screen.width)
            var mh = Number(screen.height)
            if (!isFinite(mx) || !isFinite(my) || !isFinite(mw) || !isFinite(mh)
                    || mw <= 0 || mh <= 0)
                continue

            var insideMonitor = x >= mx && x < mx + mw && y >= my && y < my + mh
            if (!insideMonitor)
                continue

            if (edge === "bottom")
                return y >= my + mh - thickness
            if (edge === "left")
                return x < mx + thickness
            if (edge === "right")
                return x >= mx + mw - thickness
            return y < my + thickness
        }
        return false
    }

    function applyCursorPosition(raw) {
        var match = String(raw || "").match(/^\s*(-?\d+)\s*,\s*(-?\d+)\s*$/)
        if (!match)
            return
        root.pointerOnBar = root.cursorOnBar(Number(match[1]), Number(match[2]))
    }

    Process {
        id: cursorProbe
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyCursorPosition(text)
        }
    }

    Timer {
        id: cursorPoll
        interval: 80
        repeat: true
        running: root.safeConfig.enabled && root.safeConfig.revealOnHover && !root.paused
        onTriggered: if (!cursorProbe.running) cursorProbe.running = true
    }

    readonly property real attenuation: GuardModel.attenuationFor({
        enabled: safeConfig.enabled,
        paused: root.paused,
        barHidden: root.barHidden,
        lit: root.lit,
        idle: root.idle,
        hovered: root.barHovered,
        revealOnHover: safeConfig.revealOnHover,
        hoverOpacity: safeConfig.hoverOpacity,
        baseOpacity: safeConfig.baseOpacity,
        idleOpacity: safeConfig.idleOpacity
    })

    readonly property real deliveredAttenuation: GuardModel.effectiveAttenuation(
        root.attenuation, safeConfig.checkerboard, safeConfig.checkerContrast)

    readonly property bool active: attenuation > 0

    function statusObject() {
        return {
            enabled: safeConfig.enabled,
            paused: root.paused,
            active: root.active,
            attenuation: Math.round(root.deliveredAttenuation * 100) / 100,
            requestedAttenuation: Math.round(root.attenuation * 100) / 100,
            mode: safeConfig.checkerboard ? "checkerboard" : "dim",
            idle: root.idle,
            hovered: root.barHovered,
            revealOnHover: safeConfig.revealOnHover,
            lit: root.lit,
            locked: root.locked,
            fullscreen: root.fullscreen,
            edge: root.edge,
            thickness: root.barThickness
        }
    }

    readonly property bool fullscreen: {
        hyprRevision // re-evaluate when the workspace payload is refreshed
        try {
            var ws = Hyprland.focusedWorkspace
            var raw = ws ? ws.lastIpcObject : null
            return raw ? !!(raw.hasfullscreen || raw.hasFullscreen) : false
        } catch (e) {
            return false
        }
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            root.hyprRevision++
        }

        function onRawEvent(event) {
            var name = ""
            try {
                name = String(event.name || "")
            } catch (e) {
                return
            }
            if (name === "fullscreen" || name === "activewindow" || name === "closewindow"
                    || name === "openwindow" || name === "workspace"
                    || name === "focusedmon" || name === "monitoradded"
                    || name === "monitorremoved") {
                Hyprland.refreshWorkspaces()
                Hyprland.refreshMonitors()
                root.hyprRevision++
                hyprSettleTimer.restart()
            }
        }
    }

    Timer {
        id: hyprSettleTimer
        interval: 120
        repeat: false
        onTriggered: root.hyprRevision++
    }

    // Idle is based on time away from the bar, not global input.
    Timer {
        id: barIdleTimer
        interval: Math.max(5, Number(root.safeConfig.idleAfterSeconds)) * 1000
        repeat: false
        running: root.safeConfig.enabled && !root.paused && !root.barHovered && !root.idle
        onTriggered: if (!root.barHovered) root.idle = true
    }

    onBarHoveredChanged: if (barHovered) root.idle = false

    onPausedChanged: if (paused) root.idle = false
    onConfigChanged: root.idle = false

    Timer {
        id: phaseTimer
        running: root.safeConfig.enabled && root.safeConfig.checkerboard
        interval: root.safeConfig.checkerPhaseMinutes * 60 * 1000
        repeat: true
        onTriggered: root.phase = (root.phase + 1) % 2
    }

    Variants {
        model: Quickshell.screens

        Overlay {
            edge: root.edge
            thickness: root.barThickness
            attenuation: root.attenuation
            checkerboard: root.safeConfig.checkerboard
            checkerContrast: root.safeConfig.checkerContrast
            suspendOnFullscreen: root.safeConfig.suspendOnFullscreen
            hyprRevision: root.hyprRevision
            phaseX: GuardModel.phaseOffset(root.phase).x
            phaseY: GuardModel.phaseOffset(root.phase).y
            fadeMs: root.safeConfig.fadeMs
            revealMs: root.safeConfig.revealMs
            hovered: root.barHovered
            revealOnHover: root.safeConfig.revealOnHover
        }
    }

    IpcHandler {
        target: "oledguard"

        function status(): string {
            return JSON.stringify(root.statusObject())
        }

        function pause(): string {
            root.paused = true
            return "paused"
        }

        function resume(): string {
            root.paused = false
            return "resumed"
        }

        function toggle(): string {
            root.paused = !root.paused
            return root.paused ? "paused" : "resumed"
        }

    }


}
