#!/system/bin/sh
set -e
MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/package_list.sh"
. "$MODDIR/lib/paths.sh"
. "$MODDIR/lib/config_env.sh"
detect_root_solution

log "SERVICE" "Setting boot properties"

_feature_enabled() { [ "$(cfg_get "$1" 1)" != "0" ]; }

# Early boot props (immediate, no wait)
apply_boot_props

# Protect SELinux policy files
if [ "$(toybox cat /sys/fs/selinux/enforce 2>/dev/null)" = "0" ]; then
  chmod 640 /sys/fs/selinux/enforce 2>/dev/null || true
  chmod 440 /sys/fs/selinux/policy 2>/dev/null || true
fi

log "SERVICE" "Boot properties set"

# After boot completed
# KernelSU / APatch: boot-completed.sh handles hardening
[ "$KSU" = "true" ] && {
  log "SERVICE" "KernelSU/APatch detected - boot-completed.sh handles hardening"
  exit 0
}

# Magisk: poll sys.boot_completed, then apply hardening
log "SERVICE" "Magisk detected - waiting for boot completion"
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 1
done
log "SERVICE" "Boot completed - applying hardening"

# Apply boot hardening (settings + prop deletes)
_feature_enabled toggle_boot_hardening && {
  apply_boot_hardening
  # Harden sensitive proc files
  chmod 440 /proc/cmdline 2>/dev/null || true
  chmod 440 /proc/net/unix 2>/dev/null || true
  find /vendor/bin /system/bin -name install-recovery.sh -exec chmod 440 {} + 2>/dev/null || true
  chmod 750 /system/addon.d 2>/dev/null || true
}
_feature_enabled toggle_dev_options && disable_dev_options
log "SERVICE" "Boot hardening applied"


# Hide TWRP / OrangeFox / FOX recovery folders from /sdcard
if _feature_enabled toggle_recovery; then
  log "SERVICE" "Hiding recovery folders..."
  hide_recovery_folders
  log "SERVICE" "Recovery folders hidden"
fi

log "SERVICE" "Running boot-time features..."

_feature_enabled toggle_security_patch && sh "$MODDIR/features/security_patch.sh" 2>/dev/null || true

_feature_enabled toggle_suspicious_props && sh "$MODDIR/features/suspicious_props.sh" >/dev/null 2>&1 || true

# Block ROM spoof engines in background (uses sp_persist — not safe inline at boot)
_feature_enabled toggle_rom_spoof && ( block_rom_spoof_engines ) &

log "SERVICE" "Boot-time features done"

# Delayed spoofing - 120s delay to re-apply props that system may have overridden
(
  sleep 120
  log "SERVICE" "Delayed spoofing - reapplying critical props"
  sp_try ro.crypto.state encrypted
  sp_try ro.build.tags release-keys
  hide_recovery_folders
) &

# Periodic suspicious props cleaning - re-run every hour
_feature_enabled toggle_suspicious_props && (
  while true; do
    sleep 3600
    sh "$MODDIR/features/suspicious_props.sh" >/dev/null 2>&1 || true
  done
) &

log "SERVICE" "Done"
