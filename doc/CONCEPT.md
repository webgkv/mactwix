# MacTwix

> macOS system tweak utility — menubar app for applying network and performance fixes.
> Like GNOME Tweaks, but for macOS. Lives in the menu bar.

## Concept

MacTwix is a native macOS menubar app that lets you toggle hidden system
optimizations with one click. No Terminal needed, no remembering sysctl commands.

The name is a mashup of **Mac** + **Tweak** + **Fix** (Twix).

### Target audience

- macOS users experiencing slow Wi-Fi, especially with torrents or multi-connection workloads
- Power users who want control over hidden system knobs
- Intel and Apple Silicon Macs (Monterey through Tahoe)

## Features (v1.0 — MVP)

### Network Fixes

| Fix | What it does | Reversible |
|-----|-------------|-----------|
| **AWDL Kill** | `ifconfig awdl0 down` — stops AirDrop channel-switching interference | Yes |
| **TCP Optimization** | Applies 17 sysctl knobs (TSO, ECN, buffers, MSS, IAJ, CUBIC) | Yes |
| **Smart Auto-mode** | AWDL off only when torrent client is running, auto-restores on quit | Yes |

### UI Layout (menubar dropdown)

```
┌─────────────────────────────────┐
│  🍫 MacTwix              v1.0  │
├─────────────────────────────────┤
│  Network                        │
│  ├─ ● TCP Optimized      [ON]  │
│  ├─ ● AWDL Disabled      [ON]  │
│  └─ ● Auto AWDL (Smart)  [ON]  │
├─────────────────────────────────┤
│  AirDrop                        │
│  └─ Enable temporarily →        │
├─────────────────────────────────┤
│  App Triggers                   │
│  ├─ qBittorrent          ✓     │
│  ├─ Deluge               ✓     │
│  ├─ Transmission         ✓     │
│  └─ + Add app...               │
├─────────────────────────────────┤
│  Status                         │
│  ├─ Wi-Fi: 585 Mbit (ch 40)   │
│  ├─ AWDL: DOWN                 │
│  └─ Signal: -55 dBm            │
├─────────────────────────────────┤
│  ⚙ Preferences...              │
│  ↺ Apply All at Login     [ON] │
│  ─────────────────────────────  │
│  Quit MacTwix                   │
└─────────────────────────────────┘
```

## Architecture

### Technology

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (`MenuBarExtra`, no main window)
- **Minimum OS:** macOS 13 (Ventura) — works through Tahoe
- **Privileges:** Privileged LaunchDaemon via **SMAppService** (not SMJobBless)
- **IPC:** XPC (`com.webgkv.mactwix.helper`)
- **Build:** XcodeGen (`project.yml`) → `MacTwix.xcodeproj`, no external deps

### Components

```
MacTwix.app
├── Contents/MacOS/MacTwix              # menubar UI
├── Contents/MacOS/MacTwixHelper        # root daemon binary
└── Contents/Library/LaunchDaemons/
    └── com.webgkv.mactwix.helper.plist
```

App registers the daemon once (`SMAppService.daemon.register`). User approves in
**System Settings → Login Items**. After that, toggles call into the helper over XPC;
the helper runs `sysctl` / `ifconfig` / Auto AWDL watchdog as root.

### Privilege Escalation

1. **SMAppService daemon** (current) — one-time Login Items approval, then silent.
2. ~~SMJobBless~~ — deprecated; do not use for new work.
3. ~~osascript admin~~ — password every time; only acceptable as a last-resort fallback.

Uninstall: app asks helper to rollback TCP/AWDL, then `SMAppService.unregister()`.

### Process Watching (Smart Auto-mode)

Runs **inside the helper** (survives app quit) via `NSWorkspace` + 3s timer.

### Apple Silicon Considerations

On Ventura+ (especially Apple Silicon), macOS re-enables AWDL automatically.
Workarounds:
1. **Watchdog timer** — re-disable every 2-3 seconds while torrent is active
2. **Disable Universal Control** via defaults write (prevents AWDL reactivation)
3. **Channel 149 recommendation** — suggest user to set router to channel 149
   (AWDL's preferred channel — eliminates channel switching entirely)

## Future Features (v2.0+)

| Feature | Description |
|---------|-------------|
| **Finder tweaks** | Show hidden files, disable .DS_Store on network, etc. |
| **Dock tweaks** | Auto-hide delay, recent apps, minimize effect |
| **Kernel tuning** | Additional sysctl knobs for disk, memory |
| **Profile system** | "Gaming", "Work", "Download" profiles with different settings |
| **Channel advisor** | Read current Wi-Fi channel, recommend 149 if mismatch |
| **Notifications** | Alert when AWDL re-enables, or when speed drops |
| **Brew install** | `brew install --cask mactwix` |

## Research & References

- AWDL interference: https://www.networkweather.com/learn/awdl/
- awdl-symphonizer: https://github.com/tbraun96/awdl-symphonizer
- Meter.com PSA (Apple-recommended AWDL disable): https://www.meter.com/mac-osx-awdl-psa
- Apple Community threads: M1/M2/M3 all affected
- Our fix-tcp-tahoe.sh sysctl values: tested on Intel Broadcom BCM43602
- macOS re-enables AWDL on Ventura+: https://apple.stackexchange.com/questions/451646

## Branding

- **Name:** MacTwix
- **Icon:** Stylized chocolate bar (two sticks) with a gear/wrench motif
- **Tagline:** "Tweak. Fix. Enjoy."
- **License:** MIT (open source)
- **Repo:** github.com/webgkv/mactwix (planned)
