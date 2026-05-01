# Development Guide — Yurikey Manager

For full architecture reference, see [ARCHITECTURE.md](./ARCHITECTURE.md).

## Quick Reference

| Area | Files | Lines |
|---|---|---|
| `src/lib/` | 5 shared libraries | 193 total |
| `src/features/` | 16 feature scripts | varies |
| `src/webroot/js/` | 17 ES modules | 1550 total |
| `src/webroot/css/app.css` | 1 stylesheet | 790 |
| `src/webroot/index.html` | 1 HTML page | 458 |

## WebUI Architecture

### Bridge (`src/webroot/js/bridge.js`)

3-tier fallback to execute shell commands:

1. `window.ksu.exec` — KernelSU/APatch native bridge
2. `window.YuriKeyHost.execScript` — Magisk via MMRL
3. `window.execYurikeyScript` — legacy MMRL fallback

Returns an event emitter with `on('data')` and `on('exit')` for live streaming to the terminal.

### Config Persistence (`src/webroot/js/cfg.js`)

```js
cfgGet(key, default)     # ksud module config get → cat config/*.val
cfgSet(key, value)       # ksud module config set → printf > config/*.val
```

Mirrors `lib/config_env.sh` on the shell side. On first load, migrates legacy `localStorage` settings.

### Script Execution (`src/webroot/js/app.js`)

Two modes:
- **Simple mode**: progress dialog, toast on completion, output history saved
- **Dev mode**: live terminal with real-time stdout/stderr, toggled via dev-mode switch

### Theme (`src/webroot/js/theme.js`)

MWC Material 3 via CSS custom properties. 5 color presets (ocean, rose, forest, sunset, violet). Auto dark/light detection. Monet dynamic colors from wallpaper (Android 12+).

## Pipeline System

Pipelines are text files in `src/pipelines/` listing feature scripts to run:

```
# src/pipelines/full_integrity
gms.sh
target.sh
security_patch.sh
boot_hash.sh
keybox.sh
pif.sh?
```

- `?` suffix = optional (skipped if file missing, pipeline continues)
- Any script exiting non-zero **aborts** the pipeline
- The `orchestrator.sh` reads the pipeline file line by line

To create a new pipeline: write a text file in `src/pipelines/`, then call `sh orchestrator.sh <name>`.

## Boot Flow

```
KernelSU / APatch:
  service.sh         → immediate ro.* property resets
  boot-completed.sh  → apply_boot_hardening(), override.description

Magisk:
  service.sh         → ro.* resets + poll sys.boot_completed + apply_boot_hardening()
```

The `apply_boot_hardening()` function (in `lib/common.sh`) runs `settings put` and `resetprop --delete` for security hardening. Extracted as function because it's called from 3 places.

## Config Persistence (`lib/config_env.sh`)

Dual-layer approach:
- **KernelSU**: uses `ksud module config get/set/delete`
- **Magisk/APatch**: falls back to flat files in `/data/adb/Yurikey/config/*.val`

Both layers are controlled by the same `cfg_get`/`cfg_set`/`cfg_delete` API. The WebUI mirrors this via shell `exec()`.

## Feature Script Patterns

### Idempotency

All features must be safe to run multiple times. Check prerequisites before acting:

```sh
check_network || { log "FEATURE" "Error: No internet"; exit 1; }
[ -d "/data/adb/tricky_store" ] || { log "FEATURE" "Error: Tricky Store not found"; exit 1; }
```

### Logging

Use the `log()` function from `lib/common.sh`:

```sh
log "FEATURE" "Start"
log "FEATURE" "Downloading..."
log "FEATURE" "Finish"
```

Format: `2026-05-02 12:00:00 [FEATURE] message`

## RKA Subsystem

`src/rka/jsonarray.sh` is a pure-awk JSON array manipulation library. Used by `features/rka.sh` to provision Remote Key Attestation config for the PassIt app. The config file lives at `/data/user/<UID>/io.github.mhmrdd.libxposed.ps.passit/files/rka_configs.json`.
