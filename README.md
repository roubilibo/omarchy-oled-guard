# OLED Guard

Omarchy plugin yang mengurangi luminance bar untuk membantu mengurangi risiko
burn-in OLED. Veil hanya menutupi area bar, tidak mengambil input, dan otomatis
terangkat saat pointer berada di bar atau saat konten fullscreen aktif.

![OLED Guard panel](preview.png)

## Instalasi

```bash
omarchy plugin add https://github.com/roubilibo/omarchy-oled-guard.git --enable
omarchy restart shell
```

Hapus plugin:

```bash
omarchy plugin remove roubilibo.oled-guard
```

## Konfigurasi

Entry plugin berada di `~/.config/omarchy/shell.json`. Preset dapat diubah
langsung melalui `levels`; tooltip panel akan mengikuti angka terbaru.

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

`baseOpacity` dan `idleOpacity` lama tetap didukung untuk konfigurasi lama.
Jika `level` digunakan, nilai di `levels` menjadi sumber utama.

Perubahan JSON diterapkan sebagai satu snapshot ke service, overlay, dan panel;
tidak perlu restart shell. Restart hanya diperlukan setelah mengubah source
plugin.

### Arti idle

Idle berarti tidak ada pointer yang melewati bar selama `idleAfterSeconds`.
Aktivitas mouse di luar bar tidak mereset timer ini. Default-nya 90 detik.

### Mode

- **Flat**: dimming merata dan paling efisien.
- **Checker**: menambahkan tekstur checkerboard; rata-rata attenuation sama,
  tetapi sedikit kurang efisien untuk wear.
- **Reveal on hover**: veil dilepas saat pointer berada di area bar.

## Panel dan perintah

Klik kiri icon untuk membuka panel. Klik kanan untuk pause/resume.
Tooltip level menampilkan angka `working` dan `idle` dari konfigurasi aktif.

Status service:

```bash
omarchy-shell oledguard status
omarchy-shell oledguard pause
omarchy-shell oledguard resume
omarchy-shell oledguard toggle
```

Kontrol panel dan level:

```bash
omarchy-shell roubilibo.oled-guard level off|light|medium|deep|veiled
omarchy-shell roubilibo.oled-guard mode off|dim|checker
omarchy-shell roubilibo.oled-guard reveal always|hover
omarchy-shell roubilibo.oled-guard look flat|checker
omarchy-shell roubilibo.oled-guard toggle
omarchy-shell roubilibo.oled-guard state
```

Pause tidak disimpan ke JSON. Gunakan `"enabled": false` jika ingin
menonaktifkan plugin secara permanen.

## Persyaratan

Omarchy 4.x dengan shell berbasis Quickshell. Tidak ada dependency tambahan.

## Lisensi

MIT
