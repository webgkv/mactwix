#!/usr/bin/env bash
#
# macOS Tahoe / Sequoia 15.6+ TCP stack workaround for slow BitTorrent and
# high-throughput multi-connection workloads (TSO, ECN lottery, IAJ throttling).
#
# System-level TCP sysctl fix only (no qBittorrent / app settings).
#
# Usage:
#   ./fix-tcp-tahoe.sh                   # list all options
#   sudo ./fix-tcp-tahoe.sh --install    # apply now + LaunchDaemon (survives reboot)
#   sudo ./fix-tcp-tahoe.sh --rollback   # remove LaunchDaemon, restore Apple defaults
#   ./fix-tcp-tahoe.sh --status          # show daemon + sysctl state
#   sudo ./fix-tcp-tahoe.sh --dry-run --install
#
# Internal (called by LaunchDaemon at boot):
#   sudo ./fix-tcp-tahoe.sh --apply-runtime
#
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PLIST_SRC="${SCRIPT_DIR}/local.system.fix-tcp-tahoe.plist"
readonly PLIST_DST="/Library/LaunchDaemons/local.system.fix-tcp-tahoe.plist"
readonly LABEL="local.system.fix-tcp-tahoe"
readonly STATE_DIR="${SCRIPT_DIR}/.state"
readonly BACKUP_FILE="${STATE_DIR}/pre-apply-sysctl.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=0
MODE="help"
PROFILE="fix"   # fix | experimental

readonly SYSCTL_KEYS="
net.inet.tcp.tso
net.inet.tcp.ecn_initiate_out
net.inet.tcp.ecn_setup_percentage
net.inet.tcp.mssdflt
net.inet.tcp.delayed_ack
net.inet.tcp.win_scale_factor
net.inet.tcp.autorcvbufmax
net.inet.tcp.autosndbufmax
net.inet.tcp.sendspace
net.inet.tcp.recvspace
net.inet.tcp.recv_allowed_iaj
net.inet.tcp.acc_iaj_react_limit
net.inet.tcp.recv_throttle_minwin
net.inet.tcp.local_slowstart_flightsize
net.inet.tcp.cubic_tcp_friendliness
net.inet.tcp.cubic_fast_convergence
net.inet.tcp.cubic_use_minrtt
"

# Extra knobs only for --experimental (sporting interest A/B on Tahoe CUBIC)
readonly EXPERIMENTAL_KEYS="
net.inet.tcp.use_newreno
net.inet.tcp.do_ack_compression
net.inet.tcp.cubic_rfc_compliant
net.inet.tcp.cubic_minor_fixes
net.inet.tcp.rack
net.inet.tcp.ack_compression_rate
"

log_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  cat <<EOF
macOS Tahoe / Sequoia 15.6+ — system TCP sysctl workaround
Scope: kernel net.inet.tcp.* only. qBittorrent settings are separate.

Usage:
  $(basename "$0")                     show this help
  sudo $(basename "$0") --install      apply sysctl + install LaunchDaemon (persists reboot)
  sudo $(basename "$0") --experimental apply fix + experimental CUBIC/RACK/NewReno knobs (runtime)
  sudo $(basename "$0") --rollback     remove LaunchDaemon + restore Apple defaults
  $(basename "$0") --status            compare current / optimized / Apple-default values
  sudo $(basename "$0") --dry-run --install   preview install actions

Options:
  --install, -i       apply optimized sysctl values and register boot LaunchDaemon
  --apply, -a         alias for --install
  --experimental, -e  apply optimized + experimental knobs (use_newreno, no ack compression, rack off, …)
  --rollback, -r      undo: remove LaunchDaemon, restore pre-apply snapshot or Apple defaults
  --restore-defaults  alias for --rollback
  --status, -s        print LaunchDaemon + sysctl table
  --dry-run, -n       with --install/--rollback: print commands, do not change system
  --apply-runtime     internal: apply sysctl only (used by LaunchDaemon)
  -h, --help          same as no arguments

Installs:
  ${PLIST_DST}

State:
  ${BACKUP_FILE}  (snapshot before first --install, used by --rollback)

Optimized sysctl keys (17):
$(while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    printf '  %s=%s\n' "$key" "$(fix_value "$key")"
  done <<<"$SYSCTL_KEYS")
EOF
}

fix_value() {
  case "$1" in
    net.inet.tcp.tso)                         echo 0 ;;
    net.inet.tcp.ecn_initiate_out)            echo 0 ;;
    net.inet.tcp.ecn_setup_percentage)        echo 0 ;;
    net.inet.tcp.mssdflt)                     echo 1460 ;;
    net.inet.tcp.delayed_ack)                 echo 0 ;;
    net.inet.tcp.win_scale_factor)            echo 8 ;;
    net.inet.tcp.autorcvbufmax)               echo 33554432 ;;
    net.inet.tcp.autosndbufmax)               echo 33554432 ;;
    net.inet.tcp.sendspace)                   echo 262144 ;;
    net.inet.tcp.recvspace)                   echo 262144 ;;
    net.inet.tcp.recv_allowed_iaj)            echo 100 ;;
    net.inet.tcp.acc_iaj_react_limit)         echo 10000 ;;
    net.inet.tcp.recv_throttle_minwin)        echo 4194304 ;;
    net.inet.tcp.local_slowstart_flightsize)  echo 20 ;;
    net.inet.tcp.cubic_tcp_friendliness)      echo 1 ;;
    net.inet.tcp.cubic_fast_convergence)      echo 1 ;;
    net.inet.tcp.cubic_use_minrtt)            echo 1 ;;
    *) return 1 ;;
  esac
}

experimental_value() {
  case "$1" in
    net.inet.tcp.use_newreno)                 echo 1 ;;
    net.inet.tcp.do_ack_compression)          echo 0 ;;
    net.inet.tcp.cubic_rfc_compliant)         echo 0 ;;
    net.inet.tcp.cubic_minor_fixes)           echo 0 ;;
    net.inet.tcp.rack)                        echo 0 ;;
    net.inet.tcp.ack_compression_rate)        echo 2 ;;
    *) fix_value "$1" ;;
  esac
}

apple_default() {
  case "$1" in
    net.inet.tcp.tso)                         echo 1 ;;
    net.inet.tcp.ecn_initiate_out)            echo 2 ;;
    net.inet.tcp.ecn_setup_percentage)        echo 100 ;;
    net.inet.tcp.mssdflt)                     echo 512 ;;
    net.inet.tcp.delayed_ack)                 echo 3 ;;
    net.inet.tcp.win_scale_factor)            echo 3 ;;
    net.inet.tcp.autorcvbufmax)               echo 4194304 ;;
    net.inet.tcp.autosndbufmax)               echo 4194304 ;;
    net.inet.tcp.sendspace)                   echo 131072 ;;
    net.inet.tcp.recvspace)                   echo 131072 ;;
    net.inet.tcp.recv_allowed_iaj)            echo 5 ;;
    net.inet.tcp.acc_iaj_react_limit)         echo 200 ;;
    net.inet.tcp.recv_throttle_minwin)        echo 0 ;;
    net.inet.tcp.local_slowstart_flightsize)  echo 8 ;;
    net.inet.tcp.cubic_tcp_friendliness)      echo 0 ;;
    net.inet.tcp.cubic_fast_convergence)      echo 0 ;;
    net.inet.tcp.cubic_use_minrtt)            echo 0 ;;
    net.inet.tcp.use_newreno)                 echo 0 ;;
    net.inet.tcp.do_ack_compression)          echo 1 ;;
    net.inet.tcp.cubic_rfc_compliant)         echo 1 ;;
    net.inet.tcp.cubic_minor_fixes)           echo 1 ;;
    net.inet.tcp.rack)                        echo 1 ;;
    net.inet.tcp.ack_compression_rate)        echo 5 ;;
    *) return 1 ;;
  esac
}

require_macos() {
  [[ "$(uname -s)" == Darwin ]] || {
    log_error "macOS only."
    exit 1
  }
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || {
    log_error "Root required: sudo $0 $*"
    exit 1
  }
}

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] $*"
  else
    "$@"
  fi
}

sysctl_read() {
  local key="$1"
  sysctl -n "$key" 2>/dev/null || echo "?"
}

backup_current_values() {
  local key
  mkdir -p "$STATE_DIR"
  {
    echo "# captured $(date -u +"%Y-%m-%dT%H:%M:%SZ") before apply"
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      printf '%s=%s\n' "$key" "$(sysctl_read "$key")"
    done <<<"$SYSCTL_KEYS"
  } >"$BACKUP_FILE"
  log_ok "Saved pre-apply snapshot: ${BACKUP_FILE}"
}

apply_values_from() {
  local source_fn="$1"
  local args=() key val
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    val="$("$source_fn" "$key")" || continue
    args+=("${key}=${val}")
  done <<<"$SYSCTL_KEYS"
  run_cmd sysctl -w "${args[@]}"
}

install_launchdaemon() {
  if [[ ! -f "$PLIST_SRC" ]]; then
    log_error "Missing plist: ${PLIST_SRC}"
    exit 1
  fi
  run_cmd cp "$PLIST_SRC" "$PLIST_DST"
  run_cmd chown root:wheel "$PLIST_DST"
  run_cmd chmod 644 "$PLIST_DST"
  run_cmd launchctl bootout "system/${LABEL}" 2>/dev/null || true
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] launchctl bootstrap system ${PLIST_DST}"
  else
    launchctl bootstrap system "$PLIST_DST"
    launchctl enable "system/${LABEL}"
  fi
  log_ok "LaunchDaemon installed: ${PLIST_DST}"
}

remove_launchdaemon() {
  if [[ -f "$PLIST_DST" ]]; then
    run_cmd launchctl bootout "system/${LABEL}" 2>/dev/null || true
    run_cmd rm -f "$PLIST_DST"
    log_ok "LaunchDaemon removed: ${PLIST_DST}"
  else
    log_info "LaunchDaemon not installed."
  fi
}

restore_from_backup() {
  local args=() line key val
  if [[ ! -f "$BACKUP_FILE" ]]; then
    return 1
  fi
  log_info "Restoring from snapshot: ${BACKUP_FILE}"
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    args+=("${key}=${val}")
  done <"$BACKUP_FILE"
  if ((${#args[@]} > 0)); then
    run_cmd sysctl -w "${args[@]}"
    log_ok "Restored pre-apply snapshot."
    return 0
  fi
  return 1
}

show_status() {
  local key current fix apple daemon state keys
  daemon="not installed"
  [[ -f "$PLIST_DST" ]] && daemon="installed (${PLIST_DST})"

  echo ""
  echo "LaunchDaemon: ${daemon}"
  printf '\n%-36s %10s %10s %10s %s\n' "KEY" "CURRENT" "FIX" "APPLE" "STATE"
  printf '%.0s-' {1..90}; echo

  keys="$SYSCTL_KEYS"$'\n'"$EXPERIMENTAL_KEYS"
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    current="$(sysctl_read "$key")"
    if fix_value "$key" >/dev/null 2>&1; then
      fix="$(fix_value "$key")"
    else
      fix="$(apple_default "$key")"
    fi
    apple="$(apple_default "$key")"
    if [[ "$current" == "$fix" ]]; then
      state="${GREEN}optimized${NC}"
    elif [[ "$current" == "$apple" ]]; then
      state="${CYAN}apple default${NC}"
    else
      state="${YELLOW}custom${NC}"
    fi
    printf '%-36s %10s %10s %10s ' "$key" "$current" "$fix" "$apple"
    echo -e "$state"
  done <<<"$keys"
  echo ""
}

disable_awdl() {
  if ifconfig awdl0 2>/dev/null | grep -q "UP"; then
    run_cmd ifconfig awdl0 down
    log_ok "AWDL (awdl0) disabled — fixes Wi-Fi throughput on Intel Macs."
    log_warn "AirDrop will not work until: sudo ifconfig awdl0 up"
  else
    log_info "AWDL already down."
  fi
}

do_apply() {
  require_root
  backup_current_values
  apply_values_from fix_value
  disable_awdl
  install_launchdaemon
  log_ok "TCP + Wi-Fi Tahoe fix applied (persists across reboot)."
  show_status
  echo ""
  log_ok "Done."
}

do_apply_runtime() {
  require_root
  apply_values_from fix_value
}

do_experimental() {
  require_root
  local key val args=()
  log_warn "Experimental profile: NewReno + no ACK compression + RACK off + non-RFC CUBIC knobs."
  log_warn "Base optimized keys stay; LaunchDaemon still re-applies base fix on boot (not experimental)."
  # Ensure base fix is on
  apply_values_from fix_value
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    val="$(experimental_value "$key")" || continue
    args+=("${key}=${val}")
  done <<<"$EXPERIMENTAL_KEYS"
  run_cmd sysctl -w "${args[@]}"
  log_ok "Experimental sysctl applied (this boot until reboot / base LaunchDaemon)."
  show_status
}

do_rollback() {
  require_root
  remove_launchdaemon
  if restore_from_backup; then
    log_ok "Rollback complete (pre-apply snapshot)."
  else
    log_warn "No snapshot; applying documented Apple defaults."
    apply_values_from apple_default
    log_ok "Rollback complete (Apple factory defaults for this boot)."
    log_warn "Reboot recommended to fully clear kernel-cached state."
  fi
  show_status
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install|-i|--apply|-a) MODE="install" ;;
      --experimental|-e) MODE="experimental" ;;
      --apply-runtime) MODE="apply-runtime" ;;
      --rollback|--restore-defaults|-r) MODE="rollback" ;;
      --status|-s) MODE="status" ;;
      --dry-run|-n) DRY_RUN=1 ;;
      -h|--help) MODE="help" ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  require_macos
  parse_args "$@"

  case "$MODE" in
    help) usage ;;
    install) do_apply ;;
    experimental) do_experimental ;;
    apply-runtime) do_apply_runtime ;;
    rollback) do_rollback ;;
    status) show_status ;;
  esac
}

main "$@"
