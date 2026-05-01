log() { echo "$(date +%Y-%m-%d\ %H:%M:%S) [$1] $2"; }

die() { log "ERROR" "$1"; exit 1; }

download() {
    _dl_url="$1" _dl_oldpath="$PATH"
    PATH="/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH"
    if command -v curl >/dev/null 2>&1; then
        curl --connect-timeout 10 -Ls "$_dl_url"
    else
        wget -T 10 -qO- "$_dl_url"
    fi
    PATH="$_dl_oldpath"
    unset _dl_url _dl_oldpath
}

check_network() {
  _cn_endpoint="https://clients3.google.com/generate_204"
  _cn_oldpath="$PATH"
  PATH="/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH"
  if command -v curl >/dev/null 2>&1; then
    curl --connect-timeout 5 -sI "$_cn_endpoint" >/dev/null 2>&1 && PATH="$_cn_oldpath" && return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -T 5 --spider "$_cn_endpoint" >/dev/null 2>&1 && PATH="$_cn_oldpath" && return 0
  fi
  PATH="$_cn_oldpath"
  return 1
}

check_module() {
  _cm_name="$1"
  if [ ! -d "/data/adb/modules/$_cm_name" ] && [ ! -d "/data/adb/modules_update/$_cm_name" ]; then
    log "ERROR" "Required module '$1' is not installed"
    return 1
  fi
  return 0
}

check_command() {
  _cc_name="$1"
  if ! command -v "$_cc_name" >/dev/null 2>&1; then
    log "ERROR" "Required command '$1' not found on this device"
    return 1
  fi
  return 0
}

check_prop() {
    _cp_name=$1 _cp_expected=$2
    _cp_value=$(resetprop "$_cp_name")
    [ -z "$_cp_value" ] || [ "$_cp_value" = "$_cp_expected" ] || resetprop -n "$_cp_name" "$_cp_expected"
    unset _cp_name _cp_expected _cp_value
}

contains_check_prop() {
    _ccp_name=$1 _ccp_contains=$2 _ccp_newval=$3
    case "$(resetprop "$_ccp_name")" in
        *"$_ccp_contains"*) resetprop -n "$_ccp_name" "$_ccp_newval"; unset _ccp_name _ccp_contains _ccp_newval; return 0 ;;
    esac
    unset _ccp_name _ccp_contains _ccp_newval
    return 1
}

ensure_dir() { mkdir -p "$1" 2>/dev/null; }

_escape_json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

apply_boot_hardening() {
  settings put global development_settings_enabled 0
  settings put global adb_enabled 0
  settings put global oem_unlock_allowed 0
  settings put global adb_wifi_enabled 0
  settings put global adb_wifi_port -1
  resetprop --delete persist.service.adb.enable 2>/dev/null || true
  resetprop --delete persist.service.debuggable 2>/dev/null || true
  resetprop -n persist.sys.developer_options 0
}

version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a,A,"."); split(b,B,".");
    for(i=1;i<=3;i++) {
      if(A[i]+0 > B[i]+0) { exit 0 }
      if(A[i]+0 < B[i]+0) { exit 1 }
    }
    exit 0
  }'
}

run_device_info() {
  for _rdi_root in "$@"; do
    [ -f "$_rdi_root/webroot/common/device-info.sh" ] && sh "$_rdi_root/webroot/common/device-info.sh" && return 0
  done
  for _rdi_p in \
    "/data/adb/modules_update/Yurikey/webroot/common/device-info.sh" \
    "/data/adb/modules/yurikey/webroot/common/device-info.sh"; do
    [ -f "$_rdi_p" ] && sh "$_rdi_p" && return 0
  done
  return 1
}
