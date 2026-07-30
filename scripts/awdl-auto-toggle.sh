#!/usr/bin/env bash
#
# Auto-toggle AWDL based on running torrent clients.
# When any torrent client is running → AWDL OFF (max throughput).
# When all torrent clients close → AWDL ON (AirDrop available).
#
# Runs as a LaunchDaemon, polling every 5 seconds.
#
set -Euo pipefail

readonly POLL_INTERVAL=5
readonly LOG_TAG="awdl-auto-toggle"

# Process names to watch (case-insensitive grep patterns)
readonly TORRENT_APPS=(
  "qbittorrent"
  "Deluge"
  "Transmission"
  "uTorrent"
  "BitTorrent"
  "Vuze"
  "tixati"
)

log() { logger -t "$LOG_TAG" "$*"; }

awdl_is_up() {
  ifconfig awdl0 2>/dev/null | grep -q "UP"
}

torrent_running() {
  for app in "${TORRENT_APPS[@]}"; do
    if pgrep -iq "$app" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

main_loop() {
  local prev_state="unknown"

  log "Started. Watching for: ${TORRENT_APPS[*]}"

  while true; do
    if torrent_running; then
      if [[ "$prev_state" != "torrent_on" ]]; then
        ifconfig awdl0 down 2>/dev/null || true
        log "Torrent client detected → AWDL OFF"
        prev_state="torrent_on"
      fi
    else
      if [[ "$prev_state" != "torrent_off" ]]; then
        ifconfig awdl0 up 2>/dev/null || true
        log "No torrent clients → AWDL ON"
        prev_state="torrent_off"
      fi
    fi
    sleep "$POLL_INTERVAL"
  done
}

main_loop
