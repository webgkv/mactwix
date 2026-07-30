#!/usr/bin/env bash
#
# macOS Tahoe Wi-Fi performance fix — disable AWDL (AirDrop/AirPlay Direct Link)
# and tune power management for maximum throughput.
#
# Root cause: AWDL periodically switches the Wi-Fi chip to a side channel
# for AirDrop/AirPlay discovery, causing severe throughput drops on Intel Macs
# with Broadcom adapters running macOS Tahoe. Disabling AWDL restores full
# Wi-Fi throughput (10 Mbit → 100+ Mbit on torrents / multi-connection workloads).
#
# Usage:
#   sudo ./fix-wifi-tahoe.sh --install    # apply now + LaunchDaemon (survives reboot)
#   sudo ./fix-wifi-tahoe.sh --rollback   # re-enable AWDL + remove daemon
#   ./fix-wifi-tahoe.sh --status          # show current state
#
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PLIST_LABEL="local.system.fix-wifi-tahoe"
readonly PLIST_DST="/Library/LaunchDaemons/${PLIST_LABEL}.plist"
readonly AUTO_LABEL="local.system.awdl-auto-toggle"
readonly AUTO_PLIST_SRC="${SCRIPT_DIR}/local.system.awdl-auto-toggle.plist"
readonly AUTO_PLIST_DST="/Library/LaunchDaemons/${AUTO_LABEL}.plist"
readonly AUTO_SCRIPT="${SCRIPT_DIR}/awdl-auto-toggle.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

require_macos() {
  [[ "$(uname -s)" == Darwin ]] || { log_error "macOS only."; exit 1; }
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { log_error "Root required: sudo $0 $*"; exit 1; }
}

awdl_is_up() {
  ifconfig awdl0 2>/dev/null | grep -q "status: active"
}

show_status() {
  echo ""
  echo "=== Wi-Fi Tahoe Fix Status ==="
  echo ""

  # AWDL
  local awdl_state
  if ifconfig awdl0 2>/dev/null | grep -q "UP"; then
    awdl_state="${RED}UP (active — hurts performance)${NC}"
  else
    awdl_state="${GREEN}DOWN (disabled — good)${NC}"
  fi
  echo -e "  AWDL (awdl0):        $awdl_state"

  # LaunchDaemon
  local daemon_state
  if [[ -f "$PLIST_DST" ]]; then
    daemon_state="${GREEN}installed${NC}"
  else
    daemon_state="${YELLOW}not installed${NC}"
  fi
  echo -e "  LaunchDaemon:        $daemon_state"

  # Power management
  local womp tcpka
  womp=$(pmset -g 2>/dev/null | awk '/^ womp/{print $2}')
  tcpka=$(pmset -g 2>/dev/null | awk '/^ tcpkeepalive/{print $2}')
  echo -e "  Wake on LAN (womp): ${womp:-?}"
  echo -e "  TCP Keep Alive:     ${tcpka:-?}"

  # Wi-Fi link info
  local airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
  if [[ -x "$airport" ]]; then
    local rate rssi noise channel
    rate=$("$airport" -I 2>/dev/null | awk '/lastTxRate/{print $2}')
    rssi=$("$airport" -I 2>/dev/null | awk '/agrCtlRSSI/{print $2}')
    noise=$("$airport" -I 2>/dev/null | awk '/agrCtlNoise/{print $2}')
    channel=$("$airport" -I 2>/dev/null | awk '/channel/{print $2}')
    echo ""
    echo "  Wi-Fi link rate:    ${rate:-?} Mbit"
    echo "  RSSI / Noise:       ${rssi:-?} / ${noise:-?} dBm"
    echo "  Channel:            ${channel:-?}"
  fi
  echo ""
}

do_apply() {
  log_info "Disabling AWDL (awdl0)..."
  ifconfig awdl0 down 2>/dev/null || true

  log_info "Tuning power management..."
  pmset -a womp 0 2>/dev/null || true
  pmset -a tcpkeepalive 0 2>/dev/null || true

  log_info "Installing LaunchDaemon to persist across reboots..."
  cat > "$PLIST_DST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/sbin/ifconfig</string>
        <string>awdl0</string>
        <string>down</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/${PLIST_LABEL}.err</string>
</dict>
</plist>
EOF
  chown root:wheel "$PLIST_DST"
  chmod 644 "$PLIST_DST"
  launchctl bootout "system/${PLIST_LABEL}" 2>/dev/null || true
  launchctl bootstrap system "$PLIST_DST"
  launchctl enable "system/${PLIST_LABEL}"

  log_ok "Wi-Fi fix applied."
  log_ok "AWDL disabled — AirDrop will NOT work until rollback."
  log_warn "If you need AirDrop temporarily: sudo ifconfig awdl0 up"
  show_status
}

do_rollback() {
  log_info "Re-enabling AWDL..."
  ifconfig awdl0 up 2>/dev/null || true

  log_info "Restoring power management defaults..."
  pmset -a womp 1 2>/dev/null || true
  pmset -a tcpkeepalive 1 2>/dev/null || true

  if [[ -f "$PLIST_DST" ]]; then
    launchctl bootout "system/${PLIST_LABEL}" 2>/dev/null || true
    rm -f "$PLIST_DST"
    log_ok "LaunchDaemon removed."
  fi

  log_ok "Rollback complete. AWDL re-enabled."
  show_status
}

do_airdrop_on() {
  ifconfig awdl0 up 2>/dev/null || true
  log_ok "AWDL enabled — AirDrop available. Wi-Fi throughput may degrade."
  log_info "Disable again: sudo $(basename "$0") --airdrop off"
}

do_airdrop_off() {
  ifconfig awdl0 down 2>/dev/null || true
  log_ok "AWDL disabled — full Wi-Fi throughput restored. AirDrop unavailable."
}

do_auto() {
  log_info "Installing AWDL auto-toggle daemon..."
  log_info "AWDL will be OFF while any torrent client runs, ON otherwise."

  chmod +x "$AUTO_SCRIPT"
  cp "$AUTO_PLIST_SRC" "$AUTO_PLIST_DST"
  chown root:wheel "$AUTO_PLIST_DST"
  chmod 644 "$AUTO_PLIST_DST"

  # Remove the static AWDL-down daemon if present (auto-toggle replaces it)
  if [[ -f "$PLIST_DST" ]]; then
    launchctl bootout "system/${PLIST_LABEL}" 2>/dev/null || true
    rm -f "$PLIST_DST"
    log_info "Removed static AWDL fix (replaced by auto-toggle)."
  fi

  launchctl bootout "system/${AUTO_LABEL}" 2>/dev/null || true
  launchctl bootstrap system "$AUTO_PLIST_DST"
  launchctl enable "system/${AUTO_LABEL}"

  log_ok "Auto-toggle daemon installed."
  log_ok "Torrent running → AWDL off. No torrent → AWDL on (AirDrop works)."
  log_info "Logs: /tmp/awdl-auto-toggle.out, system log (tag: awdl-auto-toggle)"
}

do_auto_remove() {
  if [[ -f "$AUTO_PLIST_DST" ]]; then
    launchctl bootout "system/${AUTO_LABEL}" 2>/dev/null || true
    rm -f "$AUTO_PLIST_DST"
    log_ok "Auto-toggle daemon removed."
  else
    log_info "Auto-toggle daemon not installed."
  fi
  ifconfig awdl0 up 2>/dev/null || true
  log_ok "AWDL re-enabled."
}

usage() {
  cat <<EOF
macOS Tahoe Wi-Fi Performance Fix
Disables AWDL to prevent channel-switching interference on Intel Macs.

Usage:
  sudo $(basename "$0") --install          disable AWDL always + LaunchDaemon
  sudo $(basename "$0") --auto             smart mode: AWDL off only when torrent runs
  sudo $(basename "$0") --auto-remove      remove auto-toggle daemon
  sudo $(basename "$0") --rollback         re-enable AWDL + remove all daemons
  sudo $(basename "$0") --airdrop on       temporarily enable AirDrop
  sudo $(basename "$0") --airdrop off      disable AirDrop again (restore speed)
  $(basename "$0") --status                show current state

Modes:
  --install    Always keep AWDL off (max speed, no AirDrop ever)
  --auto       AWDL off only while qBittorrent/Deluge/Transmission runs (recommended)
  --rollback   Remove everything, restore defaults
EOF
}

main() {
  require_macos
  case "${1:-}" in
    --install|-i|--apply|-a)
      require_root
      do_apply
      ;;
    --rollback|-r|--restore)
      require_root
      do_rollback
      ;;
    --auto)
      require_root
      do_auto
      ;;
    --auto-remove)
      require_root
      do_auto_remove
      ;;
    --airdrop)
      require_root
      case "${2:-}" in
        on|up|enable)   do_airdrop_on ;;
        off|down|disable) do_airdrop_off ;;
        *) log_error "Usage: --airdrop on|off"; exit 1 ;;
      esac
      ;;
    --status|-s)
      show_status
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
