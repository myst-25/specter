# Yurikey Manager — Architecture

## Philosophy

- **ES modules + Vite** for the WebUI (builds MWC + JS into bundled output)
- **Runtime bridge detection** — works on KernelSU (`window.ksu`), APatch (identical `window.ksu`), and Magisk via MMRL (`window.YuriKeyHost`). No single-vendor lock-in.
- **`@material/web` (MWC)** — Google's official Material 3 Web Components
- **`ksud module config`** instead of `localStorage` (survives app uninstall)
- **`boot-completed.sh`** for KernelSU/APatch (proper boot event) + **`service.sh` with `sys.boot_completed` polling fallback** for Magisk
- **`config_env.sh`** — shared config persistence layer with `ksud` + file fallback (works on Magisk/APatch/KSU)
- **Zero CDN dependencies at runtime** — everything bundled locally by Vite
- **Single shared shell library** (`lib/`) — eliminates all copy-paste
- **Single orchestrator** for both action button and WebUI
- **`$MODDIR` everywhere** — no hardcoded paths

---

## Directory Layout

```
yurikey/
├── .github/workflows/
│   ├── build-test.yml                    # CI: lint + build + test
│   └── build-release.yml                 # CI: build, sign, release
│
├── src/                                  # SOURCE directory (developer edits here)
│   ├── META-INF/
│   │   └── com/google/android/
│   │       ├── update-binary             # Magisk legacy installer (184 lines)
│   │       └── updater-script            # Contains only: #MAGISK
│   │
│   ├── module.prop                       # Module metadata
│   │
│   ├── lib/                              # Shared shell libraries (single source of truth)
│   │   ├── paths.sh                      #   All module & system path constants
│   │   ├── urls.sh                       #   All remote URLs (keybox, configs, update)
│   │   ├── common.sh                     #   Shared functions: log(), download(), die(), check_prop(),
│   │   │                                 #   _escape_json(), apply_boot_hardening(), version_ge(),
│   │   │                                 #   run_device_info()
│   │   ├── config_env.sh                 #   Config persistence: ksud module config with file fallback
│   │   └── package_list.sh              #   Fixed target.txt entries + all app lists
│   │
│   ├── features/                         # One file = one feature, one responsibility
│   │   ├── keybox.sh                     #   Download & install keybox
│   │   ├── target.sh                     #   Generate target.txt
│   │   ├── security_patch.sh             #   Spoof security patch date
│   │   ├── boot_hash.sh                  #   Set verified boot hash
│   │   ├── pif.sh                        #   Update Play Integrity Fix fingerprints
│   │   ├── pif2.sh                       #   Clean PIF props (pihook/pixelprops)
│   │   ├── hma.sh                        #   Deploy HMA-OSS config
│   │   ├── znctl.sh                      #   Configure Zygisk Next
│   │   ├── rka.sh                        #   Provision remote key attestation
│   │   ├── cleanup.sh                    #   Clear all detection traces
│   │   ├── gms.sh                        #   Kill & clear Google Play Store
│   │   ├── kill_all.sh                   #   Kill all detector apps
│   │   ├── widevine.sh                   #   Fix Widevine L1
│   │   ├── lsposed.sh                    #   Clean LSPosed ODEX traces
│   │   ├── twrp.sh                       #   Delete TWRP folder
│   │   └── keybox_info.sh               #   Check keybox status/revocation
│   │
│   ├── orchestrator.sh                   # Single entry point for all pipelines
│   │
│   ├── pipelines/                        # Pipeline definitions (text files)
│   │   ├── full_integrity                #   gms → target → security_patch → boot_hash → keybox → pif
│   │   └── root_hide                     #   hma → znctl
│   │
│   ├── customize.sh                      # Installation (sourced by installer — uses $MODPATH)
│   ├── service.sh                        # Boot-time property spoofer (late_start service)
│   ├── boot-completed.sh                 # KernelSU/APatch only: runs at ACTION_BOOT_COMPLETED
│   ├── uninstall.sh                      # Clean removal (sourced — uses $MODDIR from $0)
│   ├── action.sh                         # Thin wrapper → calls orchestrator.sh
│   │
│   ├── rka/                              # Remote Key Attestation subsystem
│   │   └── jsonarray.sh                  #   Shell JSON array library (pure awk)
│   │
│   └── webroot/                          # WebUI SOURCE (Vite bundles this → Module/webroot/)
│       ├── config.json                   # KernelSU WebUI config (title, icon)
│       ├── index.html                    # Single HTML — MWC components declared here
│       ├── css/
│       │   └── app.css                   # MWC theme vars + page layout (~746 lines)
│       ├── js/                           # 17 JS modules
│       │   ├── app.js                    # Main entry — wires UI, navigation, actions
│       │   ├── bridge.js                 # 3-tier bridge detection (ksu/mmrl/legacy)
│       │   ├── cfg.js                    # Config persistence (ksud + file fallback)
│       │   ├── clock.js                  # Clock display
│       │   ├── contributors.js           # Contributor grid
│       │   ├── dev-mock.js               # Dev mock for browser testing
│       │   ├── device.js                 # Device info + keybox status refresh
│       │   ├── history.js                # Script output history viewer
│       │   ├── i18n.js                   # Async translation loader
│       │   ├── material.js               # MWC component imports
│       │   ├── network.js                # Online/offline detection
│       │   ├── preload.js                # Preload MWC icon
│       │   ├── redirect.js               # URL opener (injection-safe)
│       │   ├── terminal.js               # Live terminal output
│       │   ├── theme.js                  # Theme engine (monet + presets)
│       │   ├── toast.js                  # Toast notifications
│       │   └── utils.js                  # escapeHtml()
│       ├── json/
│       │   ├── dev.json                  # Contributors list
│       │   ├── module_paths.json         # Runtime module path (written by customize.sh)
│       │   └── info.json                 # Device info (generated by device-info.sh)
│       ├── lang/
│       │   ├── source/string.json        # English source strings
│       │   └── *.json                    # 9 translation files (ar, de, es, fr, hi, pt, ru, tr, zh)
│       ├── assets/
│       │   ├── material-icons.css        # Material Icons font CSS
│       │   └── material-icons-outlined.css
│       ├── color-vars.html               # MD3 color visualizer tool (dev only)
│       └── common/                       # WebUI-triggered scripts
│           ├── device-info.sh            # Sources lib/common.sh for log() consistency
│           ├── lsposed2.sh               # Delegates to features/lsposed.sh
│           ├── twrp.sh                   # Delegates to features/twrp.sh
│           ├── pif2.sh                   # Delegates to features/pif2.sh
│           ├── widevinel1.sh             # Fix Widevine L1 (direct copy + execute)
│           └── FixWidevineL1/
│               └── FixWidevineL1.sh      # KmInstallKeybox wrapper with 3-path probe
│
├── Module/                               # BUILD OUTPUT (auto-generated by `npm run build`)
│   └── ...                               # Identical structure, webroot/ is Vite-bundled
│
├── vite.config.js                        # Vite config: root=src/webroot, outDir=Module/webroot
├── package.json                          # deps: @material/web, @material/material-color-utilities. devDeps: vite
├── .gitignore
├── docs/
│   ├── ARCHITECTURE.md
│   ├── AGENTS.md
│   ├── CONTRIBUTING.md
│   └── DEVELOPMENT.md
├── changelog.md
├── README.md
├── config.json                           # HMA-OSS config file (root for download, not bundled)
├── update.json                           # OTA update manifest
└── module.zip                            # Built module zip (auto-generated)
```

---

## Execution Flow

```
Action button
  → action.sh
    → detects if sourced (Magisk) or subprocess (KSU) via "${0##*/}"
    → MODDIR=${0%/*}; . "$MODDIR/lib/common.sh"
    → sh "$MODDIR/orchestrator.sh" full_integrity
      → reads pipelines/full_integrity
      → sh features/gms.sh
      → sh features/target.sh
      → sh features/security_patch.sh
      → sh features/boot_hash.sh
      → sh features/keybox.sh
      → sh features/pif.sh?          (? = optional, skips if file missing with warning)
    → run_device_info "$MODDIR"       (writes webroot/json/info.json)

WebUI button
  → bridge detection (tries window.ksu → YuriKeyHost → execYurikeyScript)
  → reads module_paths.json → MODULE.MODDIR
  → spawnScript(scriptName, 'feature')
  → stdout/stderr piped to dialog + history log
  → features/keybox.sh             (same script, same contract)

Boot (KernelSU / APatch):
  → service.sh (late_start service, non-blocking)
    → check_prop() for ro.boot.*, ro.build.*, ro.debuggable, etc.
  → boot-completed.sh (at ACTION_BOOT_COMPLETED)
    → apply_boot_hardening()       (settings put + resetprop)
    → cfg_set for override.description

Boot (Magisk):
  → service.sh (late_start service)
    → check_prop() for ro.boot.*, ro.build.* (same as KSU)
    → polls sys.boot_completed (while/getprop loop) for post-boot actions
    → apply_boot_hardening()       (done inline in service.sh)
```

---

## Contracts & Patterns

### `return` vs `exit` — The Boundary Rule (With Context Detection)

| Context | Execution Method | Use |
|---|---|---|
| Feature scripts (`features/*.sh`) | `sh features/foo.sh` (subprocess) | **`exit`** |
| Orchestrator (`orchestrator.sh`) | `sh orchestrator.sh` (subprocess) | **`exit`** |
| Library scripts (`lib/*.sh`) | Sourced via `. lib/common.sh` | **Never call `exit` or `return` at top level** |
| `customize.sh` | Sourced by installer | **`return`** |
| `service.sh` | Subprocess (Magisk/KSU runs it) | **`exit`** |
| `boot-completed.sh` | Subprocess (KSU runs it) | **`exit`** |
| `uninstall.sh` | Sourced by installer | **`return`** |
| `action.sh` | KSU: subprocess. Magisk: sourced. | **Use `exit` + context detection** |

```sh
# action.sh — detects whether sourced or subprocess
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

sh "$MODDIR/orchestrator.sh" full_integrity || return $?

run_device_info "$MODDIR"

[ "${0##*/}" = "action.sh" ] && exit 0 || return 0
```

The detection `"${0##*/}" = "action.sh"` works because:
- When **sourced** (Magisk): `$0` is the caller's name (installer or manager script), NOT `action.sh`
- When **run as subprocess** (KSU): `$0` is `action.sh`

### Every Script Follows Path Contracts

All scripts use `MODDIR=${0%/*}` to locate themselves. The path to `lib/` is relative to each script's location:

| Script location | `$MODDIR` resolves to | Path to `lib/common.sh` |
|---|---|---|
| `features/keybox.sh` | `.../Yurikey/features` | `"$MODDIR/../lib/common.sh"` |
| `orchestrator.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `service.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `boot-completed.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `action.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `customize.sh` | **N/A — sourced by installer** | Use `$MODPATH` (provided by installer) |
| `uninstall.sh` | `.../Yurikey` | `"$MODDIR/lib/common.sh"` |
| `webroot/common/device-info.sh` | `.../Yurikey/webroot/common` | Strips 3 levels to module root, then `lib/common.sh` |

### Feature Script Contract

```sh
#!/system/bin/sh
MODDIR=${0%/*}               # resolves to .../Yurikey/features
. "$MODDIR/../lib/common.sh" # go up one level to module root, then into lib/
. "$MODDIR/../lib/paths.sh"

log "FEATURE" "Start"
# ... one responsibility, idempotent, check prerequisites first ...
log "FEATURE" "Finish"
exit 0
```

- Exits `0` on success, `1` on failure
- All output via `log()`
- **Idempotent** — safe to run multiple times
- **Checks prerequisites** — if a required module is missing, `exit 0` (skip gracefully)

### Root-Level Script Contract (orchestrator.sh, service.sh, boot-completed.sh, action.sh)

```sh
MODDIR=${0%/*}               # resolves to .../Yurikey/
. "$MODDIR/lib/common.sh"    # lib/ is directly under module root
. "$MODDIR/lib/paths.sh"
```

### Installer Script Contract (customize.sh, uninstall.sh)

```sh
# customize.sh — sourced by installer, MODPATH is provided by environment
. "$MODPATH/lib/common.sh"

# uninstall.sh — sourced by uninstaller, MODDIR works here
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
```

### Orchestrator With Conditional Execution

```sh
while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "${line#\#}" != "$line" ] && continue

    feature="$line"
    optional=false
    [ "${feature%\?}" != "$feature" ] && optional=true && feature="${feature%\?}"

    FEATURE_PATH="$MODDIR/features/$feature"
    if [ "$optional" = "true" ] && [ ! -f "$FEATURE_PATH" ]; then
        log "ORCH" "Warning: Optional feature '$feature' not found — skipping"
        continue
    fi

    log "ORCH" "Running: $feature"
    if ! sh "$FEATURE_PATH"; then
        die "Pipeline aborted: $feature failed"
    fi
done < "$PIPELINE_FILE"
```

### Pipeline Definitions

**`pipelines/full_integrity`:**
```
gms.sh
target.sh
security_patch.sh
boot_hash.sh
keybox.sh
pif.sh?
```

**`pipelines/root_hide`:**
```
hma.sh
znctl.sh?
```

---

## Boot — Dual Strategy (KernelSU `boot-completed.sh` + Magisk Polling Fallback)

**KernelSU / APatch** support a dedicated `boot-completed.sh` that runs at `ACTION_BOOT_COMPLETED`.
**Magisk** does NOT support this — it only has `service.sh` (late_start service).

This architecture uses **both**, with a conditional check:

```sh
# src/boot-completed.sh — KernelSU/APatch only: runs EXACTLY at boot completed
MODDIR=${0%/*}
# Guard: KernelSU and APatch both set $KSU=true; skip if not running under them
[ -z "$KSU" ] && exit 0

. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/paths.sh"
. "$MODDIR/lib/config_env.sh"

log "BOOT" "Boot completed — finalizing"

apply_boot_hardening

# Dynamic module description
if [ -f "$TARGET_FILE" ]; then
  cfg_set "override.description" "Active | $(getprop ro.build.version.release)"
else
  cfg_set "override.description" "Run action button to set up keybox"
fi
```

```sh
# src/service.sh — runs on BOTH KernelSU and Magisk (late_start service)
# On KernelSU/APatch: only sets ro.* properties (boot-completed.sh handles the rest)
# On Magisk: sets ro.* properties AND polls sys.boot_completed for post-boot actions
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

log "SERVICE" "Setting boot properties"

# ro.* properties (safe to set immediately at late_start)
check_prop "ro.boot.vbmeta.device_state" "locked"
check_prop "ro.boot.verifiedbootstate"   "green"
# ... (all ro.* props) ...

# Magisk fallback: poll sys.boot_completed for settings that need a booted system
if [ "$KSU" != "true" ]; then
  log "SERVICE" "Magisk detected — polling sys.boot_completed"
  while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
  done
  apply_boot_hardening
  log "SERVICE" "Boot hardening applied"
else
  log "SERVICE" "KernelSU/APatch detected — boot-completed.sh will handle hardening"
fi
```

**Boot script order:**
```
KernelSU / APatch:
  service.sh         → immediate property resets (ro.boot.*, ro.build.*)
  boot-completed.sh  → apply_boot_hardening(), override.description

Magisk:
  service.sh         → immediate property resets + sys.boot_completed polling for post-boot actions
```

The `apply_boot_hardening()` function (defined in `lib/common.sh`):
```sh
apply_boot_hardening() {
  settings put global development_settings_enabled 0
  settings put global adb_enabled 0
  settings put global oem_unlock_allowed 0
  settings put global adb_wifi_enabled 0
  settings put global adb_wifi_port -1
  resetprop --delete persist.service.adb.enable 2>/dev/null || true
  resetprop --delete persist.service.debuggable 2>/dev/null || true
  resetprop -n persist.sys.developer_options 0
}
```

### Root Manager Detection — Environment Variables

```sh
# KernelSU sets KSU=true, APatch also sets KSU=true (compat), Magisk sets MAGISK_VER
# service.sh's `[ "$KSU" != "true" ]` correctly identifies ONLY Magisk
# boot-completed.sh's `[ -z "$KSU" ]` checks for unset (non-KSU/non-APatch)
```

`device-info.sh` root detection order: SukiSU-Ultra → KernelSU-Next → KernelSU → APatch → Magisk.

### `module.prop`

```
id=Yurikey
name=Yurikey Manager
version=v4.0.0
versionCode=400
author=Yurikey Dev
description=A systemless module to get strong integrity so easily
banner=https://raw.githubusercontent.com/Yurii0307/yurikey/main/doc/banner.webp
updateJson=https://raw.githubusercontent.com/Yurii0307/yurikey/main/update.json
```

---

## Build Process

```sh
# One command
npm ci
npm run build
```

`npm run build` runs:
1. `vite build` → bundles `src/webroot/` (MWC + JS + CSS) into `Module/webroot/`
2. `npm run build:module` → copies shell scripts, lib/, features/, pipelines/, rka/, webroot assets/lang/json/common/ into Module/
3. Removes `Module/webroot/*.map` files
4. `npm run build:zip` → zips Module/ → `module.zip`

**`vite.config.js`:**
```js
import { defineConfig } from 'vite'
export default defineConfig({
  root: 'src/webroot',
  base: './',
  build: {
    outDir: '../../Module/webroot',
    emptyOutDir: true,
  },
})
```

**`package.json`:**
```json
{
  "name": "yurikey-module",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build && npm run build:module && rm -f Module/webroot/*.map && npm run build:zip",
    "build:module": "mkdir -p Module && cp -r src/META-INF src/module.prop src/lib src/features src/pipelines src/rka Module/ && cp src/*.sh Module/ && cp -r src/webroot/assets Module/webroot/ && cp -r src/webroot/lang Module/webroot/ && cp -r src/webroot/json Module/webroot/ && cp -r src/webroot/common Module/webroot/ && cp src/webroot/config.json Module/webroot/",
    "build:zip": "cd Module && rm -f ../module.zip && zip -r ../module.zip . && cd .."
  },
  "devDependencies": {
    "vite": "^8.0.4"
  },
  "dependencies": {
    "@material/material-color-utilities": "^0.4.0",
    "@material/web": "2.4.1"
  }
}
```

---

## Shared Library (`lib/`)

### `lib/common.sh` — Central Utility Functions

```sh
log()          # Timestamped logging: "2026-05-02 12:00:00 [FEATURE] message"
die()          # log + exit 1
download()     # curl with wget fallback (TLS validated — no --no-check-certificate)
check_network() # Connectivity check via Google generate_204
check_module()  # Verify Magisk module is installed
check_command() # Verify command exists in PATH
check_prop()    # Force-set system property to expected value
contains_check_prop()  # Conditionally override property if it contains a string
ensure_dir()    # mkdir -p
_escape_json()  # Sanitize string for JSON embedding
apply_boot_hardening()  # settings put + resetprop for security hardening
version_ge()    # Semantic version comparison (awk-based)
run_device_info()  # Find and execute device-info.sh across possible paths
```

### `lib/config_env.sh` — Config Persistence

```sh
cfg_get()    # Read config: ksud → flat-file fallback
cfg_set()    # Write config: ksud → flat-file fallback
cfg_delete() # Delete config: ksud → flat-file fallback
```

`YURIKEY_CONFIG_DIR="/data/adb/Yurikey/config"` (defined in `paths.sh`).

### `lib/package_list.sh` — App Lists

```
DETECTOR_APPS    # ~57 detector packages
GMS_APPS         # 10 Google/GMS packages
REMOTE_CONTROL_APPS  # 13 remote control apps
TOOL_APPS        # 9 tool/root apps
FIXED_TARGETS    # ~26 fixed target.txt entries with ? for optional
```

### `lib/urls.sh` — Remote URLs

```sh
KEYBOX_URL="https://yuribin.netlify.app/key"
ATTESTATION_URL="https://yuribin.netlify.app/clips/attestation"
HMA_CONFIG_URL="https://yuribin.netlify.app/clips/config"
LATEST_KEYBOX_URL="https://yuribin.netlify.app/clips/latest_keybox"
GOOGLE_REVOCATION_URL="https://android.googleapis.com/attestation/status?encrypted=1"
RKA_HOST="rp.mhmrdd.me"
RKA_TCP=59416
RKA_TOKEN="${RKA_TOKEN:-yurikey-5b70e270d6d69cd399c59ca3d62ccf6e}"  # overridable via env
```

### `lib/paths.sh` — Path Constants

```sh
TRICKY_DIR="/data/adb/tricky_store"
TARGET_FILE="$TRICKY_DIR/keybox.xml"
BACKUP_FILE="$TRICKY_DIR/keybox.xml.bak"
TARGET_TXT="$TRICKY_DIR/target.txt"
SECURITY_PATCH_FILE="$TRICKY_DIR/security_patch.txt"
TEE_STATUS="$TRICKY_DIR/tee_status"
BOOT_HASH_FILE="/data/adb/boot_hash"
HMA_DIR="/data/user/0/org.frknkrc44.hma_oss/files"
HMA_FILE="$HMA_DIR/config.json"
IDFILE="/data/local/tmp/yurid"
```

---

## WebUI Architecture

### Bridge Detection (`bridge.js`)

3-tier fallback:
1. `window.ksu.exec` → KernelSU/APatch native bridge
2. `window.YuriKeyHost.execScript` → Magisk via MMRL
3. `window.execYurikeyScript` → Legacy MMRL bridge

Returns `{ stdout, stderr }` with `on('data')` and `on('exit')` event emitters for live terminal output.

### Config Persistence (`cfg.js`)

WebUI calls `ksud module config` via shell exec, with flat-file fallback — mirrors `config_env.sh` behavior. On first load, migrates legacy `localStorage` settings.

### Script Execution (`app.js`)

Two modes:
- **Simple mode** (default): Shows a progress dialog, captures output, shows toast on completion
- **Dev mode**: Shows a live terminal with real-time stdout/stderr streaming, accessible via dev-mode toggle

### Theme (`theme.js`)

MWC Material 3 design tokens via CSS custom properties. Supports:
- 5 color presets (ocean, rose, forest, sunset, violet)
- Auto-detects system dark/light via `prefers-color-scheme`
- Monet dynamic color extraction from wallpaper (Android 12+)

### i18n (`i18n.js`)

Async translation loader using `lang/*.json` files. English uses `source/string.json`. Falls back gracefully. Supports `data-i18n` on light DOM content and `data-i18n-label` on MWC component `label` attributes.

---

## `customize.sh` — Installer

`customize.sh` is **sourced by the installer**, so `${0%/*}` does NOT point to the module directory. Uses `$MODPATH` (provided by the installer environment):

```sh
. "$MODPATH/lib/common.sh"
. "$MODPATH/lib/urls.sh"
. "$MODPATH/lib/paths.sh"

# Check dependencies
if [ ! -d "/data/adb/modules/tricky_store" ] && [ ! -d "/data/adb/modules_update/tricky_store" ]; then
  ui_print "- Error: Tricky Store dependency is not installed"
  return 0
fi

# Download and install keybox with full error handling
if check_network; then
  download "$KEYBOX_URL" > "$TEMP_FILE"
  if [ ! -f "$TEMP_FILE" ] || [ ! -s "$TEMP_FILE" ]; then
    ui_print "- Error: Keybox download failed"
  else
    mkdir -p "$TRICKY_DIR"
    if ! base64 -d "$TEMP_FILE" > "$DECODE_FILE" 2>/dev/null; then
      ui_print "- Error: Downloaded keybox is corrupted"
    else
      # Compare with existing, backup if needed, install
      ...
    fi
  fi
fi

# Write module_paths.json for WebUI path discovery
mkdir -p "$MODPATH/webroot/json"
RUNTIME_DIR=$(echo "$MODPATH" | sed 's|/modules_update/|/modules/|')
cat > "$MODPATH/webroot/json/module_paths.json" <<JSON
{"MODDIR": "$RUNTIME_DIR"}
JSON

# Bootstrap device info
run_device_info "$TMPDIR" "$MODPATH"

return 0
```

---

## Feature Reference

| Feature | Pipeline | Description | Prerequisites |
|---|---|---|---|
| `gms.sh` | full_integrity | Force-stop + clear Play Store cache | None |
| `target.sh` | full_integrity | Generate Tricky Store target.txt | Tricky Store |
| `security_patch.sh` | full_integrity | Spoof security patch date to previous month | Tricky Store |
| `boot_hash.sh` | full_integrity | Write vbmeta digest for boot hash | None |
| `keybox.sh` | full_integrity | Download + install base64 keybox | Network, Tricky Store |
| `pif.sh` | full_integrity? | Update Play Integrity Fix fingerprint | Network, PIF installed |
| `hma.sh` | root_hide | Deploy HMA-OSS config | Network, HMA-OSS installed |
| `znctl.sh` | root_hide? | Configure Zygisk Next (denylist, memory, linker) | Zygisk Next >= 1.3.0 |
| `rka.sh` | — | Provision Remote Key Attestation config | PassIt installed |
| `cleanup.sh` | — | Clear detector traces, temp files, ADB props | Boot completed |
| `kill_all.sh` | — | Force-stop + clear all detector + GMS apps | None |
| `widevine.sh` | — | Download attestation key + run KmInstallKeybox | Network, Qualcomm device |
| `lsposed.sh` | — | Delete LSPosed base.odex traces | None |
| `twrp.sh` | — | Delete TWRP folder on internal storage | None |
| `pif2.sh` | — | Clean up pihook/pixelprops leftover props | None |
| `keybox_info.sh` | — | Check keybox version + Google revocation status | None |

---

## CI Pipeline

### `build-test.yml`
```yaml
- name: Lint shell scripts
  run: find src/ -name '*.sh' -exec shellcheck {} +
- name: Build
  run: npm ci && npm run build
- name: Verify module structure
  run: test -f Module/module.prop && test -f Module/webroot/index.html
- name: Check no hardcoded paths
  run: ! grep -rn "/data/adb/modules/Yurikey" Module/lib/ Module/features/
- name: Check no su -c in features
  run: ! grep -rn "su -c" Module/features/
```

### `build-release.yml`
Same build + extract version from changelog, update module.prop + update.json, zip signed release, create GitHub Release.

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────┐
│                     Module Root                           │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────────┐   │
│  │ customize │   │ service  │   │   boot-completed     │   │
│  │   .sh     │   │   .sh    │   │   (KSU/APatch only)  │   │
│  │ writes    │   │ + Magisk │   └──────────┬───────────┘   │
│  │ module_   │   │ fallback │    boot done (KSU) /         │
│  │ paths.json│   └────┬─────┘    inline in service (Mgk)  │
│  └────┬──────┘        │ boot                               │
│       │ install       ▼                                    │
│       ▼           ┌──────────────────────────────────┐     │
│  ┌─────────────────┤           lib/                    │     │
│  │  ┌────────────┐ ├┐ ┌──────────┐ ┌────────────────┐ ││    │
│  │  │ action.sh  │ ││ │ paths.sh │ │   urls.sh      │ ││    │
│  │  │ (thin      │ ││ │(no hard- │ │(single source  │ ││    │
│  │  │  wrapper)  │ ││ │ coded    │ │ of truth for   │ ││    │
│  │  └────────────┘ ││ │ path)    │ │ all URLs)      │ ││    │
│  │                 ││ └──────────┘ └────────────────┘ ││    │
│  │                 ││ ┌──────────────────────────────┐││    │
│  │                 ││ │       common.sh              │││    │
│  │                 ││ │ log, download, die,          │││    │
│  │                 ││ │ check_prop, _escape_json,    │││    │
│  │                 ││ │ apply_boot_hardening,        │││    │
│  │                 ││ │ version_ge, run_device_info  │││    │
│  │                 ││ └──────────────────────────────┘││    │
│  │                 ││ ┌──────────────────────────────┐││    │
│  │                 ││ │    config_env.sh             │││    │
│  │                 ││ │ cfg_get/cfg_set/cfg_delete   │││    │
│  │                 ││ │ (ksud + flat-file fallback)  │││    │
│  │                 ││ └──────────────────────────────┘││    │
│  │                 ││ ┌──────────────────────────────┐││    │
│  │                 ││ │     package_list.sh          │││    │
│  │                 ││ └──────────────────────────────┘││    │
│  │                 └──────────────────────────────────┘     │
│  │                                                            │
│  │  ┌──────────────┐     ┌─────────────────────────────┐     │
│  │  │ orchestrator │────→│     pipelines/               │     │
│  │  │    .sh       │     │  full_integrity              │     │
│  │  └──────┬───────┘     │  root_hide                   │     │
│  │         │             └─────────────────────────────┘     │
│  │         ▼                                                  │
│  │  ┌──────────────────────────────────────────────────┐     │
│  │  │               features/                           │     │
│  │  │  keybox  target  security_patch  boot_hash  pif   │     │
│  │  │  pif2  hma  znctl  rka  cleanup  gms  kill_all    │     │
│  │  │  widevine  lsposed  twrp  keybox_info              │     │
│  │  └──────────────────────────────────────────────────┘     │
│  │                                                            │
│  │  ┌──────────────────────────────────────────────────┐     │
│  │  │              webroot/ (Vite-bundled)               │     │
│  │  │  index.html → MWC @material/web 2.4.1             │     │
│  │  │  css/app.css (~746 lines, MWC theme vars)          │     │
│  │  │  js/ (17 modules: app, bridge, cfg, clock,         │     │
│  │  │      device, history, i18n, theme, toast, ...)    │     │
│  │  │  lang/ (10 language files via Crowdin)             │     │
│  │  │  json/ (module_paths.json, info.json, dev.json)    │     │
│  │  │  common/ (device-info.sh + delegates)              │     │
│  │  └──────────────────────────────────────────────────┘     │
│  │                                                            │
│  │  ┌──────────────────────────────────────────────────┐     │
│  │  │   rka/ (jsonarray.sh — pure awk JSON library)     │     │
│  └──────────────────────────────────────────────────────────┘
```

---

## File Count Summary

- `lib/` — 5 files (paths, urls, common, config_env, package_list)
- `features/` — 16 files (keybox, target, security_patch, boot_hash, pif, pif2, hma, znctl, rka, cleanup, gms, kill_all, widevine, lsposed, twrp, keybox_info)
- `pipelines/` — 2 text files (full_integrity, root_hide)
- `rka/` — 1 file (jsonarray.sh)
- `webroot/` — index.html, config.json, css/app.css, 17 JS modules, 10 lang files, 3 json files, 2 assets, 1 color-vars.html, 6 common scripts
- Root scripts — customize.sh, service.sh, boot-completed.sh, uninstall.sh, action.sh, orchestrator.sh (6 files)
