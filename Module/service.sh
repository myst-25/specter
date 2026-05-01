MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"

log "SERVICE" "Setting boot properties"

check_prop "ro.boot.vbmeta.device_state" "locked"
check_prop "ro.boot.verifiedbootstate" "green"
check_prop "ro.boot.flash.locked" "1"
check_prop "ro.boot.veritymode" "enforcing"
check_prop "ro.boot.warranty_bit" "0"
check_prop "ro.warranty_bit" "0"
check_prop "ro.debuggable" "0"
check_prop "ro.force.debuggable" "0"
check_prop "ro.secure" "1"
check_prop "ro.adb.secure" "1"
check_prop "ro.build.type" "user"
check_prop "ro.build.tags" "release-keys"
check_prop "partition.system.verified" "0"
check_prop "partition.vendor.verified" "0"
check_prop "partition.product.verified" "0"
check_prop "partition.system_ext.verified" "0"
check_prop "partition.odm.verified" "0"
check_prop "vendor.boot.vbmeta.device_state" "locked"
check_prop "vendor.boot.verifiedbootstate" "green"
check_prop "ro.vendor.boot.warranty_bit" "0"
check_prop "ro.vendor.warranty_bit" "0"
check_prop "sys.oem_unlock_allowed" "0"
check_prop "ro.oem_unlock_supported" "0"
check_prop "ro.boot.realme.lockstate" "1"
check_prop "ro.boot.realmebootstate" "green"
check_prop "ro.secureboot.lockstate" "locked"
contains_check_prop "ro.bootmode" "recovery" "unknown"
contains_check_prop "ro.boot.bootmode" "recovery" "unknown"
contains_check_prop "vendor.boot.bootmode" "recovery" "unknown"
check_prop "persist.sys.usb.config" "none"
check_prop "service.adb.root" "0"
check_prop "ro.boot.selinux" "enforcing"
check_prop "ro.boot.avb_version" "1.3"
check_prop "ro.crypto.state" "encrypted"

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

log "SERVICE" "Done"
