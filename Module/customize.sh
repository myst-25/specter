. "$MODPATH/lib/common.sh"
. "$MODPATH/lib/urls.sh"
. "$MODPATH/lib/paths.sh"

ui_print ""
ui_print "*********************************"
ui_print "*****Yuri Keybox Installer*******"
ui_print "*********************************"
ui_print ""

if [ -d "/data/adb/modules/yurikey" ]; then
  touch /data/adb/modules/yurikey/remove
  ui_print "- Removed outdated module (lowercase 'yurikey')"
fi

if [ ! -d "/data/adb/modules/tricky_store" ] && [ ! -d "/data/adb/modules_update/tricky_store" ]; then
  ui_print "- Error: Tricky Store dependency is not installed"
  ui_print "- Please install Tricky Store first."
  ui_print "- After installing Tricky Store, install the keybox from the action button or WebUI."
  return 0
fi

if [ -d "/data/adb/Yurikey/bin" ]; then
  rm -rf /data/adb/Yurikey/bin
  ui_print "- Cleaned up old binary directory"
fi

DECODE_FILE="$TRICKY_DIR/keybox_decode"
TEMP_FILE="$MODPATH/keybox.tmp"

if check_network; then
  ui_print "- Fetching remote keybox..."
  download "$KEYBOX_URL" > "$TEMP_FILE"

  if [ ! -f "$TEMP_FILE" ] || [ ! -s "$TEMP_FILE" ]; then
      ui_print "- Error: Keybox download failed. You can upload a keybox manually via the WebUI."
      rm -f "$TEMP_FILE"
  else
      mkdir -p "$TRICKY_DIR"

      if ! base64 -d "$TEMP_FILE" > "$DECODE_FILE" 2>/dev/null; then
          ui_print "- Error: Downloaded keybox is corrupted or invalid. Try again later."
          rm -f "$TEMP_FILE"
      else
          if [ -f "$TARGET_FILE" ]; then
              if cmp -s "$TARGET_FILE" "$DECODE_FILE"; then
                  ui_print "- Current keybox is already up to date. No changes needed."
                  rm -f "$TEMP_FILE" "$DECODE_FILE"
              else
                  if ! grep -q "yuriiroot" "$TARGET_FILE" 2>/dev/null; then
                      ui_print "- Previous keybox was not installed by Yuri Keybox."
                      ui_print "- Creating a backup keybox..."
                      cp "$TARGET_FILE" "$BACKUP_FILE"
                  fi
                  mv "$DECODE_FILE" "$TARGET_FILE"
                  rm -f "$TEMP_FILE"
                  ui_print "- Keybox installed successfully"
              fi
          else
              ui_print "- No keybox found! Creating a new one..."
              mv "$DECODE_FILE" "$TARGET_FILE"
              rm -f "$TEMP_FILE"
              ui_print "- Keybox installed successfully"
          fi
      fi
  fi
else
  ui_print "- No internet connection detected. Skipping keybox download."
  ui_print "- You can download a keybox later from the Actions tab."
fi

mkdir -p "$MODPATH/webroot/json"
RUNTIME_DIR=$(echo "$MODPATH" | sed 's|/modules_update/|/modules/|')
cat > "$MODPATH/webroot/json/module_paths.json" <<JSON
{"MODDIR": "$RUNTIME_DIR"}
JSON
unset RUNTIME_DIR

# Clean up v3 files from live module path
if [ -d "/data/adb/modules/Yurikey" ]; then
  if [ -d "/data/adb/modules/Yurikey/Yuri" ] || [ -f "/data/adb/modules/Yurikey/webroot/common/clear_all_detection_traces.sh" ] || [ -f "/data/adb/modules/Yurikey/webroot/common/widevinel1.sh" ] || [ -f "/data/adb/modules/Yurikey/webroot/common/lsposed2.sh" ] || [ -f "/data/adb/modules/Yurikey/webroot/common/boot_hash.sh" ]; then
    ui_print "- Detected outdated files from YuriKey v3"
    ui_print "- Cleaning up obsolete files..."
  fi
  rm -rf /data/adb/modules/Yurikey 2>/dev/null
  ui_print "- Removed old YuriKey v3 module directory"
fi

run_device_info "$TMPDIR" "$MODPATH"

return 0
