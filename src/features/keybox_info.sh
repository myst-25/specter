#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"

log "KEYBOX_INFO" "Start"

KEYBOX_FILE="/data/adb/tricky_store/keybox.xml"
INFO_PATH="$MODDIR/../webroot/json/keybox_info.json"

ensure_dir "$(dirname "$INFO_PATH")"

_installed=false
_serial=""
_is_private=false

if [ -f "$KEYBOX_FILE" ]; then
  _installed=true
  _is_private_val=$(cat "$CONFIG_DIR/kb_private.val" 2>/dev/null || echo "false")
  if [ "$_is_private_val" = "true" ]; then
    _is_private=true
  fi
  _serial=$(decode_keybox_serial "$KEYBOX_FILE" 2>/dev/null || echo "")
fi

cat <<EOF > "$INFO_PATH"
{
  "installed": $_installed,
  "serial": "$_serial",
  "is_private": $_is_private
}
EOF

unset _installed _serial _is_private _is_private_val
log "KEYBOX_INFO" "Finish"
exit 0
