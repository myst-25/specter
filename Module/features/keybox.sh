#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/urls.sh"

log "KEYBOX" "Start"

check_network || { log "KEYBOX" "Error: No internet connection"; exit 1; }

if [ ! -d "/data/adb/tricky_store" ]; then
  log "KEYBOX" "Error: Tricky Store data directory not found"
  exit 1
fi

if [ -f "$TARGET_FILE" ] && [ ! -f "$BACKUP_FILE" ]; then
  cp "$TARGET_FILE" "$BACKUP_FILE"
  log "KEYBOX" "Created backup of existing keybox"
fi

DECODE_FILE="$TRICKY_DIR/keybox_decode"
TEMP_FILE="$TRICKY_DIR/keybox.tmp"

log "KEYBOX" "Downloading keybox..."
download "$KEYBOX_URL" > "$TEMP_FILE" || {
  log "KEYBOX" "Error: Download failed"
  rm -f "$TEMP_FILE"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
  exit 1
}

if ! base64 -d "$TEMP_FILE" > "$DECODE_FILE" 2>/dev/null; then
  log "KEYBOX" "Error: Base64 decode failed"
  rm -f "$TEMP_FILE" "$DECODE_FILE"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
  exit 1
fi

if [ ! -s "$DECODE_FILE" ]; then
  log "KEYBOX" "Error: Decoded keybox is empty"
  rm -f "$TEMP_FILE" "$DECODE_FILE"
  [ -f "$BACKUP_FILE" ] && cp "$BACKUP_FILE" "$TARGET_FILE"
  exit 1
fi

mv "$DECODE_FILE" "$TARGET_FILE" || die "Failed to move decoded keybox to $TARGET_FILE"
rm -f "$TEMP_FILE"
log "KEYBOX" "Keybox installed successfully"
log "KEYBOX" "Finish"
exit 0
