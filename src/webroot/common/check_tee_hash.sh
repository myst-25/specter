#!/system/bin/sh
MODULE_ROOT="${0%/*}"
MODULE_ROOT="${MODULE_ROOT%/webroot/common}"
. "$MODULE_ROOT/lib/vbmeta.sh"

TEMP_DIR="/data/local/tmp/.specter_tee_check"
rm -rf "$TEMP_DIR" && mkdir -p "$TEMP_DIR"

_dex="$MODULE_ROOT/deps/classes.dex"
if [ -f "$_dex" ]; then
  /system/bin/app_process -Djava.class.path="$_dex" / com.dpejoh.specter.Main "$TEMP_DIR" 2>/dev/null || true

  if [ -f "$TEMP_DIR/tee_status" ]; then
    _val=$(grep -E '^(teeBroken|tee_broken)=' "$TEMP_DIR/tee_status" 2>/dev/null | cut -d= -f2)
    case "$_val" in
      true)  echo "tee_status=broken" ;;
      false) echo "tee_status=normal" ;;
      *)     echo "tee_status=unknown" ;;
    esac
  else
    echo "tee_status=error"
  fi

  if [ -f "$TEMP_DIR/tee_hash" ]; then
    echo "tee_hash=$(cat "$TEMP_DIR/tee_hash")"
  fi
else
  echo "tee_status=error (no classes.dex)"
fi

_vbmeta_slot=$(getprop ro.boot.slot_suffix 2>/dev/null || echo "")
_vbmeta_dev="/dev/block/by-name/vbmeta${_vbmeta_slot}"
[ -b "$_vbmeta_dev" ] || _vbmeta_dev="/dev/block/by-name/vbmeta"
_hash=$(vbmeta_digest "$_vbmeta_dev" 2>/dev/null || true)
[ -n "$_hash" ] && echo "vbmeta_hash=$_hash"

rm -rf "$TEMP_DIR"
