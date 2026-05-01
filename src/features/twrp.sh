#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"

log "TWRP" "Start"

TWRP_FOLDER="/storage/emulated/0/TWRP"
if [ -d "$TWRP_FOLDER" ]; then
  log "TWRP" "Deleting $TWRP_FOLDER"
  rm -rf "$TWRP_FOLDER" 2>/dev/null
  log "TWRP" "Deleted successfully"
else
  log "TWRP" "Folder $TWRP_FOLDER not found, skipping"
fi

log "TWRP" "Finish"
exit 0