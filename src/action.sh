#!/system/bin/sh
set -e
# shellcheck shell=bash
MODDIR=${0%/*}

case "$(readlink /proc/$$/exe 2>/dev/null)" in
  *busybox) set +o standalone; unset ASH_STANDALONE ;;
esac

. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/config_env.sh"

ACTION_LOG="$SPECTER_DIR/log/action.log"
ensure_dir "$SPECTER_DIR/log" 2>/dev/null
log_rotate "$ACTION_LOG"

_pif_validate_fingerprint() {
  for _f in "$SPECTER_DIR/pif.prop" "$PIF_DIR/custom.pif.prop" /data/adb/pif.prop "$PIF_DIR/pif.prop" "$PIF_DIR/custom.pif.json" "$PIF_DIR/pif.json"; do
    [ -f "$_f" ] || continue
    _fp=""
    case "$_f" in
      *.json) _fp=$(grep -o '"FINGERPRINT"[[:space:]]*:[[:space:]]*"[^"]*"' "$_f" 2>/dev/null | head -1 | sed 's/.*"FINGERPRINT"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') ;;
      *) _fp=$(sed -n 's/^FINGERPRINT=//p' "$_f" 2>/dev/null | head -1) ;;
    esac
    [ -z "$_fp" ] && continue
    case "$_fp" in
      *google*/*release-keys*) unset _f _fp; return 0 ;;
    esac
  done
  unset _f _fp
  return 1
}

{
  log_i "ACTION" "Running full integrity pipeline"

  _feature_should_run "gms" && sh "$MODDIR/features/kill_play_store.sh" || true
  _feature_should_run "target" && sh "$MODDIR/features/target.sh" --merge || true
  _feature_should_run "security_patch" && sh "$MODDIR/features/security_patch.sh" || true
  _feature_should_run "keybox" && sh "$MODDIR/features/keybox.sh" || true
  if _feature_should_run "pif"; then
    _pif_name=$(_pif_prop) || _pif_name=""
    if [ -z "$_pif_name" ]; then
      if [ -f "$SPECTER_DIR/pif_reported" ]; then
        log_d "ACTION" "PIF not found, first boot suppress (pif_reported token consumed)"
        rm -f "$SPECTER_DIR/pif_reported"
      elif [ -t 1 ]; then
        log_i "ACTION" "PIF not found. Press Volume UP to install, Volume DOWN to skip..."
        _ap_key=$(timeout 10 getevent -l 2>/dev/null | grep -oE "KEY_VOLUME(UP|DOWN)" | head -1)
        if [ "$_ap_key" = "KEY_VOLUMEUP" ]; then
          install_module_from_github "KOWX712/PlayIntegrityFix" "Play Integrity Fix" || \
            log_e "ACTION" "PIF install failed"
          log_i "ACTION" "PIF installed, reboot required before running autopif"
          _pif_installed=1
        else
          log_i "ACTION" "PIF install skipped by user"
        fi
        unset _ap_key
      else
        log_w "ACTION" "PIF not found, auto-install skipped (run from terminal or install manually)"
      fi
    elif [ -f "$SPECTER_DIR/pif_reported" ]; then
      log_i "ACTION" "PIF found, first boot - checking existing fingerprint validity"
      if _pif_validate_fingerprint; then
        log_i "ACTION" "Existing fingerprint valid, skipping fetch"
      else
        log_i "ACTION" "Fingerprint invalid or missing, fetching new"
        sh "$MODDIR/features/pif.sh" || true
      fi
      rm -f "$SPECTER_DIR/pif_reported"
      _pif_skip=1
    fi
    unset _pif_name
    if [ -z "$_pif_installed" ] && [ -z "$_pif_skip" ] && [ -f "$MODDIR/features/pif.sh" ]; then
      sh "$MODDIR/features/pif.sh" || true
    fi
  fi


  [ -f "$MODDIR/module.prop.bak" ] && cp "$MODDIR/module.prop.bak" "$MODDIR/module.prop"
  . "$MODDIR/lib/desc.sh"
  refresh_module_description

  log_i "ACTION" "Full integrity pipeline completed"
} 2>&1 | tee -a "$ACTION_LOG"

exit 0
