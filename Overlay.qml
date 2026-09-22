import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "GuardModel.js" as GuardModel

PanelWindow {
    id: overlay

    required property var modelData

    property string edge: "top"
    property int thickness: 26
    property real attenuation: 0
    property bool checkerboard: false
    property bool suspendOnFullscreen: true
    property int hyprRevision: 0
    property int phaseX: 0
    property int phaseY: 0
    property int fadeMs: 700
    property int revealMs: 170
    property bool hovered: false
    property bool revealOnHover: false

    function retime(anim, item, target) {
        var clearing = target < item.opacity
        anim.stop()
        anim.duration = clearing ? overlay.revealMs : overlay.fadeMs
        anim.easing.type = clearing ? Easing.OutCubic : Easing.InOutSine
        anim.from = item.opacity
        anim.to = target
        anim.start()
    }

    readonly property real targetFloor: layers.floor
    readonly property real targetChecker: layers.checker

    onTargetFloorChanged: retime(floorAnim, floorVeil, targetFloor)
    onTargetCheckerChanged: retime(checkerAnim, checkerVeil, targetChecker)

    NumberAnimation { id: floorAnim; target: floorVeil; property: "opacity" }
    NumberAnimation { id: checkerAnim; target: checkerVeil; property: "opacity" }

    readonly property bool verticalEdge: edge === "left" || edge === "right"

    screen: modelData

    readonly property bool screenFullscreen: {
        hyprRevision // re-evaluate when the service says the payload moved
        if (!suspendOnFullscreen)
            return false
        try {
            var monitor = Hyprland.monitorFor(modelData)
            var ws = monitor ? monitor.activeWorkspace : null
            var raw = ws ? ws.lastIpcObject : null
            return raw ? !!(raw.hasfullscreen || raw.hasFullscreen) : false
        } catch (e) {
            return false
        }
    }

    property real checkerContrast: 0.25

    readonly property real effectiveAttenuation: screenFullscreen ? 0 : attenuation
    readonly property var layers: GuardModel.veilLayers(effectiveAttenuation, checkerboard, checkerContrast)

    visible: layers.floor > 0 || layers.checker > 0
             || floorVeil.opacity > 0.001 || checkerVeil.opacity > 0.001

    color: "transparent"

    anchors {
        top: overlay.verticalEdge || overlay.edge === "top"
        bottom: overlay.verticalEdge || overlay.edge === "bottom"
        left: !overlay.verticalEdge || overlay.edge === "left"
        right: !overlay.verticalEdge || overlay.edge === "right"
    }

    implicitWidth: verticalEdge ? thickness : 0
    implicitHeight: verticalEdge ? 0 : thickness

    WlrLayershell.namespace: "oled-guard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Never reserve space or intercept bar clicks.
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    Item {
        id: veil
        anchors.fill: parent
        clip: true

        Rectangle {
            id: floorVeil
            anchors.fill: parent
            color: "black"
            opacity: 0
        }

        Image {
            id: checkerVeil
            source: Qt.resolvedUrl("checker.png")
            fillMode: Image.Tile
            opacity: 0

            x: -overlay.phaseX
            y: -overlay.phaseY
            width: parent.width + 2
            height: parent.height + 2

            smooth: false
            mipmap: false
            cache: true
        }
    }
}
