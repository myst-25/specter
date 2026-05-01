#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "ZNCTL" "Start"

REQUIRED="1.3.0"

ZYNEXT_DIR="/data/adb/modules/zygisksu"
[ ! -d "$ZYNEXT_DIR" ] && ZYNEXT_DIR="/data/adb/modules_update/zygisksu"

TARGET_FILE="$ZYNEXT_DIR/module.prop"
SCRIPT_FILE="$ZYNEXT_DIR/bin/zygiskd"

if [ ! -f "$TARGET_FILE" ]; then
  log "ZNCTL" "Error: Zygisk Next module not found"
  exit 1
fi

CURRENT=$(grep "^version=" "$TARGET_FILE" | cut -d'=' -f2 | cut -d' ' -f1)

version_ge "$CURRENT" "$REQUIRED" || {
  log "ZNCTL" "Error: Zygisk Next version too low, need $REQUIRED"
  exit 0
}

ensure_dir "$(dirname "$SCRIPT_FILE")"

znctl() {
  [ -n "$1" ] && "$SCRIPT_FILE" "$@" 2>/dev/null
}

znctl enforce-denylist just_umount
znctl memory-type anonymous
znctl linker builtin

log "ZNCTL" "Finish"
exit 0
