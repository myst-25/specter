# shellcheck shell=sh

# ---------------------------------------------------------------------------
# Specter logging framework
# ---------------------------------------------------------------------------
# Functions:
#   log     "TAG" "msg"        — legacy shim, maps to log_i
#   log_d   "TAG" "msg"        — DEBUG
#   log_i   "TAG" "msg"        — INFO   (standard operational messages)
#   log_w   "TAG" "msg"        — WARN   (recoverable issues)
#   log_e   "TAG" "msg"        — ERROR  (non-fatal failures)
#   die     "msg"              — FATAL  (logs ERROR + exits 1)
#   log_rotate path [max] [keep]
#
# Level ordering: debug < info < warn < error < silent
# Configured via $SPECTER_LOG_LEVEL (default: info).
# Logcat output: WARN+ by default (set $SPECTER_LOGCAT_LEVEL to override).
# ---------------------------------------------------------------------------

__ll_set_level() {
  case "$1" in
    debug) __ll_num=0 ;; info)  __ll_num=1 ;;
    warn)  __ll_num=2 ;; error) __ll_num=3 ;;
    silent) __ll_num=4 ;; *)    __ll_num=1 ;;
  esac
}

__ll_should_log() {
  [ "${__ll_num:-1}" -le "$1" ] 2>/dev/null
}

__ll_logcat_level() {
  case "$1" in
    debug) printf 'd' ;; info)  printf 'i' ;;
    warn)  printf 'w' ;; error) printf 'e' ;;
    fatal) printf 'f' ;; *)     printf 'i' ;;
  esac
}

__ll_init() {
  [ -n "$__ll_inited" ] && return 0
  __ll_inited=1
  __ll_set_level "${SPECTER_LOG_LEVEL:-debug}"
  __ll_lc_level="${SPECTER_LOGCAT_LEVEL:-warn}"
  __ll_lc_num=2
  case "$__ll_lc_level" in
    debug) __ll_lc_num=0 ;; info) __ll_lc_num=1 ;;
    warn)  __ll_lc_num=2 ;; error) __ll_lc_num=3 ;;
    silent) __ll_lc_num=4 ;;
  esac
}

__ll_logcat_supported=1
__ll_check_logcat() {
  [ "$__ll_logcat_supported" = "0" ] && return 1
  [ -x /system/bin/log ] 2>/dev/null && return 0
  __ll_logcat_supported=0
  return 1
}

__ll_prefix() {
  case "$1" in
    0) printf 'D' ;; 1) printf 'I' ;;
    2) printf 'W' ;; 3) printf 'E' ;;
    4) printf 'F' ;; *) printf '?' ;;
  esac
}

__ll_emit() {
  _le_level="$1" _le_tag="$2" _le_msg="$3"
  __ll_init
  __ll_should_log "$_le_level" || { unset _le_level _le_tag _le_msg; return 0; }
  _le_prefix=$(__ll_prefix "$_le_level")
  printf '[%s] [%s] %s\n' "$_le_prefix" "$_le_tag" "$_le_msg"
  if [ "$_le_level" -ge "$__ll_lc_num" ] && __ll_check_logcat; then
    /system/bin/log -t "Specter" -p "$(__ll_logcat_level "$_le_level")" "$_le_tag: $_le_msg" 2>/dev/null || true
  fi
  unset _le_level _le_tag _le_msg _le_prefix
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

log_d() { __ll_emit 0 "$1" "$2"; }
log_i() { __ll_emit 1 "$1" "$2"; }
log_w() { __ll_emit 2 "$1" "$2"; }
log_e() { __ll_emit 3 "$1" "$2"; }

log() {
  [ $# -eq 2 ] && __ll_emit 1 "$1" "$2"
}

die() {
  log_e "FATAL" "$1"
  __ll_emit 4 "FATAL" "$1"
  exit 1
}

log_rotate() {
  _lr_path="$1" _lr_max="${2:-262144}" _lr_keep="${3:-3}"
  [ -f "$_lr_path" ] || return 0
  _lr_size=$(stat -c%s "$_lr_path" 2>/dev/null || echo "0")
  [ "$_lr_size" -lt "$_lr_max" ] 2>/dev/null && return 0
  _lr_i=$_lr_keep
  while [ "$_lr_i" -ge 1 ]; do
    [ -f "${_lr_path}.$((_lr_i - 1)).gz" ] && mv "${_lr_path}.$((_lr_i - 1)).gz" "${_lr_path}.$_lr_i.gz" 2>/dev/null || true
    [ -f "${_lr_path}.$((_lr_i - 1))" ] && mv "${_lr_path}.$((_lr_i - 1))" "${_lr_path}.$_lr_i" 2>/dev/null || true
    _lr_i=$((_lr_i - 1))
  done
  command -v gzip >/dev/null 2>&1 && gzip -f "$_lr_path" 2>/dev/null || true
  : > "$_lr_path"
  unset _lr_path _lr_max _lr_keep _lr_size _lr_i
}

# Trim oldest rotated logs when total log dir exceeds a given size
log_trim() {
  _lt_dir="$1" _lt_max="${2:-5242880}"
  [ -d "$_lt_dir" ] || return 0
  _lt_total=0
  for _lt_f in "$_lt_dir"/*.gz "$_lt_dir"/*.log "$_lt_dir"/*.txt; do
    [ -f "$_lt_f" ] && _lt_total=$((_lt_total + $(stat -c%s "$_lt_f" 2>/dev/null || echo 0)))
  done
  [ "$_lt_total" -lt "$_lt_max" ] 2>/dev/null && return 0
  _lt_over=$((_lt_total - _lt_max))
  for _lt_f in $(ls -t "$_lt_dir" 2>/dev/null | grep -E '\.(gz|log\.[0-9]+)$' | while read -r _lt_name; do echo "$_lt_dir/$_lt_name"; done); do
    [ -f "$_lt_f" ] || continue
    [ "$_lt_over" -le 0 ] && break
    _lt_fsize=$(stat -c%s "$_lt_f" 2>/dev/null || echo 0)
    rm -f "$_lt_f" 2>/dev/null || true
    _lt_over=$((_lt_over - _lt_fsize))
  done
  unset _lt_dir _lt_max _lt_total _lt_over _lt_f _lt_fsize
}
