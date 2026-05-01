#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/../lib/common.sh"
. "$MODDIR/../lib/paths.sh"
. "$MODDIR/../lib/urls.sh"

KEYBOX_FILE="/data/adb/tricky_store/keybox.xml"
INFO_PATH="$MODDIR/../webroot/json/keybox_info.json"

ensure_dir "$(dirname "$INFO_PATH")"

_installed=false
_by_yuri=false
_yuri_version=""
_latest_version=""
_up_to_date=false
_revoked=false

# Extract serial number from hex-encoded DER certificate
_parse_serial() {
  _h="$1"
  # Skip outer SEQUENCE (30) + length
  case "$_h" in 30*) _h="${_h#30}" ;; *) return 1 ;; esac
  _l_hex="${_h:0:2}" _l_dec=$((16#$_l_hex))
  [ $_l_dec -ge 128 ] && _h="${_h:2 + ($_l_dec - 128) * 2}" || _h="${_h:2}"

  # Skip TBS SEQUENCE (30) + length
  case "$_h" in 30*) _h="${_h#30}" ;; *) return 1 ;; esac
  _l_hex="${_h:0:2}" _l_dec=$((16#$_l_hex))
  [ $_l_dec -ge 128 ] && _h="${_h:2 + ($_l_dec - 128) * 2}" || _h="${_h:2}"

  # Skip optional version CONTEXT [0]
  case "$_h" in
    a0*)
      _ctx_len_hex="${_h:2:2}"
      _ctx_len=$((16#$_ctx_len_hex))
      _h="${_h:4 + _ctx_len * 2}"
      ;;
  esac

  # Parse INTEGER serial
  case "$_h" in 02*) _h="${_h#02}" ;; *) return 1 ;; esac
  _l_hex="${_h:0:2}" _l_dec=$((16#$_l_hex))
  if [ $_l_dec -ge 128 ]; then
    _n=$((_l_dec - 128))
    _sl=$((16#${_h:2:_n * 2}))
    _serial_hex="${_h:2 + _n * 2:$_sl * 2}"
  else
    _serial_hex="${_h:2:$_l_dec * 2}"
  fi

  _serial=$(echo "$_serial_hex" | sed 's/^0*//')
  [ -z "$_serial" ] && _serial="0"
  return 0
}

if [ -f "$KEYBOX_FILE" ]; then
  _installed=true

  _b64=$(sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$KEYBOX_FILE" | head -20 | grep -v 'CERTIFICATE' | tr -d '\n')
  if [ -n "$_b64" ] && _hex=$(echo "$_b64" | base64 -d 2>/dev/null | od -v -tx1 | awk 'BEGIN{ORS=""} {for(i=2;i<=NF;i++) printf "%s", $i}') && _parse_serial "$_hex"; then
    log "KEYBOX_INFO" "Serial: $_serial"

    if check_network; then
      _history_json=$(download "$HISTORY_URL" 2>/dev/null)
      log "KEYBOX_INFO" "History response length: ${#_history_json}"

      if [ -n "$_history_json" ]; then
        _match=$(echo "$_history_json" | grep -o '"serial":"'"$_serial"'"')
        if [ -n "$_match" ]; then
          _by_yuri=true
          _yuri_version=$(echo "$_history_json" | grep -o '"version":"[^"]*"[^}]*"serial":"'"$_serial"'"' | sed 's/.*"version":"\([^"]*\)".*/\1/')
          [ -z "$_yuri_version" ] && _yuri_version="?"
          _latest_version=$(echo "$_history_json" | grep -o '"latest":"[^"]*"' | sed 's/"latest":"//;s/"//')
          if [ -z "$_latest_version" ]; then
            # Old server format — compute from entries
            _latest_version=$(echo "$_history_json" | grep -o '"version":"[0-9]*"' | sed 's/"version":"//;s/"//' | sort -rn | head -1)
          fi
          log "KEYBOX_INFO" "Found in history: version $_yuri_version, latest: $_latest_version"

          if [ -n "$_yuri_version" ] && [ "$_yuri_version" = "$_latest_version" ]; then
            _up_to_date=true
          else
            _revoked=true
          fi
        fi

        # Check Google for: latest Yuri (not auto-revoked) or non-Yuri
        if [ "$_by_yuri" = false ] || [ "$_up_to_date" = true ]; then
          [ "$_by_yuri" = true ] && _revoked=false && log "KEYBOX_INFO" "Latest Yuri, checking Google"
          [ "$_by_yuri" = false ] && log "KEYBOX_INFO" "Not in history, checking Google"

          _revoked_list=$(download "$GOOGLE_REVOCATION_URL" 2>/dev/null)
          if [ -n "$_revoked_list" ]; then
            # Try matching hex serial as decimal (Google uses decimal keys)
            _serial_dec=""
            if [ ${#_serial} -le 16 ]; then
              _serial_dec=$((16#$_serial))
            elif command -v bc >/dev/null 2>&1; then
              _serial_dec=$(echo "ibase=16; $(echo "$_serial" | tr 'a-f' 'A-F')" | bc | tr -d '\\\n')
            fi
            if [ -n "$_serial_dec" ] && echo "$_revoked_list" | grep -q "$_serial_dec"; then
              _revoked=true; log "KEYBOX_INFO" "REVOKED by Google"
            elif echo "$_revoked_list" | grep -qi "$_serial"; then
              _revoked=true; log "KEYBOX_INFO" "REVOKED by Google (hex match)"
            fi
          else
            log "KEYBOX_INFO" "Google response empty, skipping"
          fi
        fi
      fi
    else
      log "KEYBOX_INFO" "Network check failed"
    fi
  fi
fi

cat <<EOF > "$INFO_PATH"
{
  "installed": $_installed,
  "by_yuri": $_by_yuri,
  "yuri_version": "$(_escape_json "$_yuri_version")",
  "up_to_date": $_up_to_date,
  "revoked": $_revoked
}
EOF

unset _installed _by_yuri _yuri_version _up_to_date _revoked _b64 _hex _serial _serial_hex _history_json _match _revoked_list _latest_version _serial_dec _ctx_len_hex _ctx_len _l_hex _l_dec _n _sl
exit 0
