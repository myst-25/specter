#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"

log "PIF" "Start"

PIF_DIR="/data/adb/modules/playintegrityfix"

check_network || { log "PIF" "Error: No internet connection"; exit 1; }

if [ ! -d "$PIF_DIR" ]; then
  log "PIF" "Error: Play Integrity Fix not installed"
  exit 1
fi

MODULE_NAME=$(grep "^name=" "$PIF_DIR/module.prop" 2>/dev/null | cut -d= -f2-)
[ -z "$MODULE_NAME" ] && { log "PIF" "Error: Cannot read module.prop"; exit 1; }

case "$MODULE_NAME" in
  "Play Integrity Fix [INJECT]")
    log "PIF" "Detected INJECT variant"
    sh "$PIF_DIR/autopif_ota.sh" || log "PIF" "Warning: autopif_ota.sh failed"
    sh "$PIF_DIR/autopif.sh" || log "PIF" "Warning: autopif.sh failed"
    ;;
  "Play Integrity Fork")
    log "PIF" "Detected Fork variant"
    sh "$PIF_DIR/autopif4.sh" -m || log "PIF" "Warning: autopif4.sh failed"
    ;;
  *)
    log "PIF" "Error: Unknown module variant: $MODULE_NAME"
    exit 1
    ;;
esac

log "PIF" "Finish"
exit 0
