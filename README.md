# MacTwix

**macOS system tweak utility** — a menubar app for toggling hidden optimizations.

Like GNOME Tweaks, but for macOS. Fixes Wi-Fi, network, and system performance issues
that Apple doesn't expose in System Settings.

## What It Does

- **Fixes slow Wi-Fi** — disables AWDL (AirDrop channel-switching interference)
- **Optimizes TCP** — applies 17 sysctl knobs for maximum throughput
- **Smart Auto-mode** — AWDL off only when torrent client is running, auto-restores
- **Menubar app** — one-click toggles, no Terminal needed
- **Fully reversible** — every fix can be rolled back instantly

## Quick Start (CLI scripts)

Until the GUI is built, you can use the shell scripts directly:

```bash
# Disable AWDL + install LaunchDaemon (persists across reboots)
sudo ./scripts/fix-wifi-tahoe.sh --install

# Smart mode: AWDL off only while torrent clients run
sudo ./scripts/fix-wifi-tahoe.sh --auto

# Apply TCP optimizations
sudo ./scripts/fix-tcp-tahoe.sh --install

# Check current status
./scripts/fix-wifi-tahoe.sh --status

# Temporarily enable AirDrop
sudo ./scripts/fix-wifi-tahoe.sh --airdrop on
```

## Project Structure

```
mactwix/
├── README.md           # This file
├── doc/
│   ├── CONCEPT.md      # Full concept, architecture, UI mockup
│   └── FIXES.md        # Reference: all sysctl values and explanations
└── scripts/
    ├── fix-wifi-tahoe.sh                    # AWDL management
    ├── fix-tcp-tahoe.sh                     # TCP sysctl optimization
    ├── awdl-auto-toggle.sh                  # Auto-toggle daemon
    ├── local.system.awdl-auto-toggle.plist  # LaunchDaemon for auto-toggle
    └── local.system.fix-tcp-tahoe.plist     # LaunchDaemon for TCP fix
```

## Compatibility

| Platform | AWDL Fix | TCP Fix | Auto-mode |
|----------|----------|---------|-----------|
| Intel Mac (Tahoe) | ✅ Full | ✅ Full | ✅ |
| Apple Silicon (Ventura+) | ⚠️ Needs watchdog | ✅ Full | ✅ |

## Background

AWDL (Apple Wireless Direct Link) is a protocol used by AirDrop and AirPlay that
periodically switches your Wi-Fi chip to a side channel for device discovery.
On Intel Macs with Broadcom adapters, this causes severe throughput drops —
from ~100 Mbit to ~10 Mbit — especially with multi-connection workloads like
BitTorrent.

Disabling AWDL immediately restores full throughput. MacTwix automates this
with smart detection: AWDL off while torrenting, back on when you need AirDrop.

## License

MIT
