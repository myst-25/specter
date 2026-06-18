#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"

log "TEE" "Start"

# If a cached result exists, just log and exit
if [ -f "$TEE_STATUS" ] && [ ! -f "$SPECTER_DIR/tee_reported" ]; then
  _b=$(grep -E '^(tee_broken|tee_fallback)=' "$TEE_STATUS" 2>/dev/null | cut -d= -f2)
  log "TEE" "Status: ${_b:-$(cat "$TEE_STATUS")}"
  if [ -f "$TEE_HASH" ]; then
    _h=$(cat "$TEE_HASH")
  elif [ -f "$VBMETA_DIGEST" ]; then
    _h=$(cat "$VBMETA_DIGEST")
  fi
  [ -n "$_h" ] && log "TEE" "Hash: $_h" || log "TEE" "Hash: unavailable"
  unset _b _h
  log "TEE" "Done (cached)"
  exit 0
fi

# No cached result — run the check via app_process (needs Binder/keystore ready)
_dex="$MODDIR/../deps/classes.dex"
if [ ! -f "$_dex" ]; then
  log "TEE" "classes.dex not found at $_dex"
  exit 1
fi

sleep 5
/system/bin/app_process -Djava.class.path="$_dex" / com.dpejoh.specter.Main "$SPECTER_DIR" 2>&1 || true
rm -f "$SPECTER_DIR/tee_reported"
unset _dex

if [ -f "$TEE_STATUS" ]; then
  _b=$(grep -E '^(tee_broken|tee_fallback)=' "$TEE_STATUS" 2>/dev/null | cut -d= -f2)
  log "TEE" "Status: ${_b:-$(cat "$TEE_STATUS")}"
else
  log "TEE" "Status: unknown (no status file written)"
fi

if [ -f "$TEE_HASH" ]; then
  _h=$(cat "$TEE_HASH")
  log "TEE" "Hash: $_h"
else
  log "TEE" "Hash: unavailable"
fi
unset _b _h

log "TEE" "Done"