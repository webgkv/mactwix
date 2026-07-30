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
- **UI Framework:** SwiftUI (menubar app, no main window)
- **Minimum OS:** macOS 13 (Ventura) — works through Tahoe
- **Privileges:** Privileged helper via SMJobBless (for ifconfig, sysctl)
- **Build:** Xcode project, no external dependencies

### Components

```
MacTwix/
├── MacTwix.xcodeproj
├── MacTwix/
│   ├── MacTwixApp.swift           # @main, MenuBarExtra
│   ├── Views/
│   │   ├── MenuView.swift         # Main dropdown menu
│   │   ├── StatusView.swift       # Wi-Fi status display
│   │   └── AppTriggersView.swift  # Manage trigger apps list
│   ├── Models/
│   │   ├── NetworkFix.swift       # TCP sysctl model
│   │   ├── AWDLManager.swift      # AWDL on/off + watchdog
│   │   └── ProcessWatcher.swift   # Monitor running apps
│   ├── Helpers/
│   │   ├── PrivilegedHelper.swift # SMJobBless privileged ops
│   │   ├── ShellExecutor.swift    # Run shell commands as root
│   │   └── WiFiInfo.swift         # CoreWLAN link info
│   └── Resources/
│       ├── Assets.xcassets        # App icon (chocolate bar 🍫)
│       └── defaults.json          # Default sysctl values
├── MacTwixHelper/                 # Privileged helper tool
│   ├── main.swift
│   └── Info.plist
├── scripts/                       # Shell backends (reference)
│   ├── fix-tcp-tahoe.sh
│   ├── fix-wifi-tahoe.sh
│   └── awdl-auto-toggle.sh
└── doc/
    └── CONCEPT.md                 # This file
```

### Privilege Escalation

macOS requires root for `ifconfig` and `sysctl -w`. Options:

1. **SMJobBless** (recommended) — install privileged helper once, user approves with password, then it runs silently forever. Like Little Snitch, Bartender, etc.
2. **osascript with admin privileges** — prompts password each time. Simpler but annoying.
3. **LaunchDaemon + XPC** — daemon runs as root, app communicates via XPC. Most robust.

For v1.0: start with **osascript** (simplest), upgrade to **SMJobBless** for v1.1.

### Process Watching (Smart Auto-mode)

```swift
Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
    let apps = NSWorkspace.shared.runningApplications
    let torrentRunning = apps.contains { app in
        triggerBundleIDs.contains(app.bundleIdentifier ?? "")
    }
    if torrentRunning && awdlIsUp {
        disableAWDL()
    } else if !torrentRunning && !awdlIsUp {
        enableAWDL()
    }
}
```

Uses `NSWorkspace` (no polling via pgrep) — native, efficient, instant.

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
