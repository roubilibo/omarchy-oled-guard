.pragma library

var PLUGIN_ID = "roubilibo.oled-guard"

var DEFAULT_LEVELS = {
    light: { baseOpacity: 0.10, idleOpacity: 0.40 },
    medium: { baseOpacity: 0.15, idleOpacity: 0.55 },
    deep: { baseOpacity: 0.25, idleOpacity: 0.75 },
    veiled: { baseOpacity: 0.85, idleOpacity: 0.90 }
}

var LEVEL_NAMES = ["light", "medium", "deep", "veiled"]

var DEFAULTS = {
    enabled: true,

    baseOpacity: 0.15,
    idleOpacity: 0.55,
    idleAfterSeconds: 90,
    fadeMs: 700,
    revealMs: 170,

    checkerboard: false,
    checkerPhaseMinutes: 5,
    checkerContrast: 0.25,
    revealOnHover: false,
    hoverOpacity: 0.0,
    suspendOnFullscreen: true
}

var EDGES = ["top", "bottom", "left", "right"]

function clamp(value, lo, hi) {
    if (!isFinite(value))
        return lo
    return value < lo ? lo : (value > hi ? hi : value)
}

function asNumber(value, fallback) {
    if (value === undefined || value === null)
        return fallback
    var n = Number(value)
    return isFinite(n) ? n : fallback
}

function asBool(value, fallback) {
    if (value === undefined || value === null)
        return fallback
    return !!value
}

function normalizeLevels(raw) {
    var source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    var levels = {}
    for (var i = 0; i < LEVEL_NAMES.length; i++) {
        var name = LEVEL_NAMES[i]
        var fallback = DEFAULT_LEVELS[name]
        var candidate = source[name] && typeof source[name] === "object"
            ? source[name] : {}
        levels[name] = {
            baseOpacity: clamp(asNumber(candidate.baseOpacity, fallback.baseOpacity), 0, 0.9),
            idleOpacity: clamp(asNumber(candidate.idleOpacity, fallback.idleOpacity), 0, 0.95)
        }
    }
    return levels
}

function _levelDistance(level, baseOpacity, idleOpacity) {
    var baseDelta = level.baseOpacity - baseOpacity
    var idleDelta = level.idleOpacity - idleOpacity
    return baseDelta * baseDelta + idleDelta * idleDelta
}

function inferLevel(baseOpacity, idleOpacity, levels) {
    var base = asNumber(baseOpacity, DEFAULTS.baseOpacity)
    var idle = asNumber(idleOpacity, DEFAULTS.idleOpacity)
    var best = LEVEL_NAMES[0]
    var distance = Infinity
    for (var i = 0; i < LEVEL_NAMES.length; i++) {
        var name = LEVEL_NAMES[i]
        var candidateDistance = _levelDistance(levels[name], base, idle)
        if (candidateDistance < distance) {
            best = name
            distance = candidateDistance
        }
    }
    return best
}

function levelName(value, fallback) {
    var name = String(value || "")
    return LEVEL_NAMES.indexOf(name) === -1 ? fallback : name
}

function _findInList(list, wanted) {
    if (!list || !Array.isArray(list))
        return null
    for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (entry && String(entry.id) === wanted)
            return entry
    }
    return null
}

// Find this plugin in plugins[] or bar.layout.
function entryFor(shellConfig, id) {
    if (!shellConfig)
        return null
    var wanted = String(id || PLUGIN_ID)

    var found = _findInList(shellConfig.plugins, wanted)
    if (found)
        return found

    var layout = shellConfig.bar && shellConfig.bar.layout ? shellConfig.bar.layout : null
    if (!layout)
        return null
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
        found = _findInList(layout[sections[s]], wanted)
        if (found)
            return found
    }
    return null
}

function normalize(raw) {
    var src = raw || {}
    var levels = normalizeLevels(src.levels)
    var inferredLevel = inferLevel(src.baseOpacity, src.idleOpacity, levels)
    var activeLevel = levelName(src.level, inferredLevel)
    var selected = levels[activeLevel]
    var hasExplicitLevel = src.level !== undefined && src.level !== null
    return {
        enabled: asBool(src.enabled, DEFAULTS.enabled),
        level: activeLevel,
        levels: levels,
        // `level` is authoritative; base/idle remain for old configs.
        baseOpacity: hasExplicitLevel ? selected.baseOpacity
            : clamp(asNumber(src.baseOpacity, selected.baseOpacity), 0, 0.9),
        idleOpacity: hasExplicitLevel ? selected.idleOpacity
            : clamp(asNumber(src.idleOpacity, selected.idleOpacity), 0, 0.95),
        idleAfterSeconds: Math.round(clamp(asNumber(src.idleAfterSeconds, DEFAULTS.idleAfterSeconds), 5, 3600)),
        fadeMs: Math.round(clamp(asNumber(src.fadeMs, DEFAULTS.fadeMs), 0, 10000)),
        revealMs: Math.round(clamp(asNumber(src.revealMs, DEFAULTS.revealMs), 0, 10000)),
        checkerboard: asBool(src.checkerboard, DEFAULTS.checkerboard),
        checkerPhaseMinutes: Math.round(clamp(asNumber(src.checkerPhaseMinutes, DEFAULTS.checkerPhaseMinutes), 1, 720)),
        checkerContrast: clamp(asNumber(src.checkerContrast, DEFAULTS.checkerContrast), 0.05, 1),
        revealOnHover: asBool(src.revealOnHover, DEFAULTS.revealOnHover),
        hoverOpacity: clamp(asNumber(src.hoverOpacity, DEFAULTS.hoverOpacity), 0, 0.9),
        suspendOnFullscreen: asBool(src.suspendOnFullscreen, DEFAULTS.suspendOnFullscreen)
    }
}

function edgeFor(barConfig) {
    var position = barConfig && barConfig.position ? String(barConfig.position) : "top"
    return EDGES.indexOf(position) === -1 ? "top" : position
}

function isVerticalEdge(edge) {
    return edge === "left" || edge === "right"
}

// Resolve attenuation. Fullscreen is handled by each overlay.
function attenuationFor(state) {
    if (!state.enabled || state.paused)
        return 0
    if (state.barHidden)
        return 0
    if (!state.lit)
        return 0
    if (state.revealOnHover && state.hovered)
        return state.hoverOpacity
    return state.idle ? state.idleOpacity : state.baseOpacity
}

// Calculate the floor and checker layers for a requested attenuation.
function veilLayers(attenuation, checkerboard, checkerContrast) {
    var a = clamp(asNumber(attenuation, 0), 0, 1)
    if (!checkerboard || a <= 0)
        return { floor: a, checker: 0 }

    var k = clamp(asNumber(checkerContrast, 0.25), 0, 1)
    k = Math.min(k, a * 2)

    var floor = 1 - (1 - a) / (1 - k / 2)
    return { floor: clamp(floor, 0, 1), checker: k }
}

function effectiveAttenuation(attenuation, checkerboard, checkerContrast) {
    var layers = veilLayers(attenuation, checkerboard, checkerContrast)
    return clamp(1 - (1 - layers.floor) * (1 - layers.checker / 2), 0, 1)
}

function phaseOffset(phase) {
    var p = ((phase % 2) + 2) % 2
    return { x: p, y: 0 }
}
