MODDIR=${0%/*}
. "$MODDIR/lib/common.sh"
. "$MODDIR/lib/paths.sh"

if [ -f "$TARGET_FILE" ] && grep -q "yuriiroot" "$TARGET_FILE" 2>/dev/null; then
    if [ -f "$BACKUP_FILE" ]; then
        rm -f "$TARGET_FILE"
        mv "$BACKUP_FILE" "$TARGET_FILE"
        log "UNINSTALL" "Restored original keybox from backup"
    fi
fi

if [ -d "$BBIN" ]; then
    rm -rf "$BBIN" 2>/dev/null
    log "UNINSTALL" "Removed $BBIN"
fi

if [ -d "$YURIKEY_CONFIG_DIR" ]; then
    rm -rf "$YURIKEY_CONFIG_DIR" 2>/dev/null
    log "UNINSTALL" "Removed $YURIKEY_CONFIG_DIR"
fi

if [ -f "$MIGRATION_MARKER" ]; then
    rm -f "$MIGRATION_MARKER" 2>/dev/null
    log "UNINSTALL" "Removed migration marker"
fi

if [ -f "$BOOT_HASH_FILE" ]; then
    rm -f "$BOOT_HASH_FILE" 2>/dev/null
    log "UNINSTALL" "Removed boot hash file"
fi

if [ -f "$IDFILE" ]; then
    rm -f "$IDFILE" 2>/dev/null
    log "UNINSTALL" "Removed RKA ID file"
fi

# Clean up RKA config in PassIt app data
RKA_CFG="/data/user/$(id -u)/io.github.mhmrdd.libxposed.ps.passit/files/rka_configs.json"
if [ -f "$RKA_CFG" ]; then
    rm -f "$RKA_CFG" 2>/dev/null
    log "UNINSTALL" "Removed RKA config"
fi

return 0
