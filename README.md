# OLED Guard

An Omarchy plugin that reduces the status bar's luminance to help reduce OLED
burn-in risk. The veil covers only the bar, does not intercept input, and lifts
when the pointer reaches the bar or fullscreen content is active.

![OLED Guard panel](preview.png)

https://github.com/user-attachments/assets/f5d0a5c4-159d-4e98-a7a4-d4d4b6f55172

## Installation

```bash
omarchy plugin add https://github.com/roubilibo/omarchy-oled-guard.git --enable
omarchy restart shell
```

Remove it with:

```bash
omarchy plugin remove roubilibo.oled-guard
```

## Configuration

The plugin entry is stored in `~/.config/omarchy/shell.json`. Edit `levels` to
tune each preset; panel tooltips use the latest values.

```jsonc
{
  "id": "roubilibo.oled-guard",
  "enabled": true,
  "level": "veiled",

  "levels": {
    "light":  { "baseOpacity": 0.10, "idleOpacity": 0.40 },
    "medium": { "baseOpacity": 0.15, "idleOpacity": 0.55 },
    "deep":   { "baseOpacity": 0.25, "idleOpacity": 0.75 },
    "veiled": { "baseOpacity": 0.85, "idleOpacity": 0.90 }
  },

  "idleAfterSeconds": 90,
  "revealOnHover": true,
  "hoverOpacity": 0.0,
  "fadeMs": 700,
  "revealMs": 170,

  "checkerboard": false,
  "checkerPhaseMinutes": 5,
  "checkerContrast": 0.25,
  "suspendOnFullscreen": true
}
```

The legacy `baseOpacity` and `idleOpacity` keys are still supported. When
`level` is set, the matching entry in `levels` is authoritative.

JSON changes are applied as one snapshot to the service, overlay, and panel;
no shell restart is required. Restart the shell only after changing plugin
source files.

### Idle behavior

Idle means that the pointer has not crossed the bar for `idleAfterSeconds`.
Mouse activity outside the bar does not reset the timer. The default is 90
seconds.

### Modes

- **Flat**: uniform dimming and the most efficient mode.
- **Checker**: adds a rotating checkerboard texture; average attenuation stays
  the same, but it is slightly less efficient for OLED wear.
- **Reveal on hover**: clears the veil while the pointer is over the bar.

## Panel and commands

Left-click the bar icon to open the panel. Right-click to pause or resume.
Level tooltips show the configured `working` and `idle` percentages.

Service status:

```bash
omarchy-shell oledguard status
omarchy-shell oledguard pause
omarchy-shell oledguard resume
omarchy-shell oledguard toggle
```

Panel and level controls:

```bash
omarchy-shell roubilibo.oled-guard level off|light|medium|deep|veiled
omarchy-shell roubilibo.oled-guard mode off|dim|checker
omarchy-shell roubilibo.oled-guard reveal always|hover
omarchy-shell roubilibo.oled-guard look flat|checker
omarchy-shell roubilibo.oled-guard toggle
omarchy-shell roubilibo.oled-guard state
```

Pause is not persisted. Set `"enabled": false` to disable the plugin
persistently.

## Requirements

Omarchy 4.x with the Quickshell-based shell. No additional dependencies.

## License

MIT
