# MacTwix

**macOS system tweak utility** — menubar app for network optimizations (AWDL / TCP).

Like GNOME Tweaks, but for macOS. Applies the same fixes as the shell scripts, via a privileged helper (one-time system approval).

## Status

- ✅ Menubar app (`MacTwix`) + privileged helper (`MacTwixHelper`) via **SMAppService**
- ✅ TCP optimize / rollback, AWDL on/off, Auto AWDL, uninstall
- ✅ CLI scripts kept as reference / emergency fallback (`scripts/`)
- ⏳ Requires selecting your **Personal Team** in Xcode once (free Apple ID)

## Build (from source — recommended)

1. Install Xcode 15+ (macOS 13+).
2. Open `MacTwix.xcodeproj` (or regenerate: `brew install xcodegen && xcodegen generate`).
3. Xcode → **Settings → Accounts** → add your Apple ID (free is fine).
4. Select target **MacTwix** → **Signing & Capabilities** → Team → **Personal Team**.
5. Repeat for target **MacTwixHelper** (same Team).
6. Product → **Build** (⌘B), then **Run** (⌘R).

Optional: put your Team ID in `Config/Local.xcconfig` (gitignored):

```
DEVELOPMENT_TEAM = YOURTEAMID
```

### First launch

1. Menubar → **Install Helper**
2. Enable MacTwix in **System Settings → General → Login Items**
3. Use toggles (TCP / AWDL / Auto). No password per toggle after that.
4. **Uninstall Helper…** rolls back settings and unregisters the daemon.

Gatekeeper may warn on unsigned/ad‑hoc downloads. Building from this source with *your* Team avoids that on your machine.

## Project layout

```
mactwix/
├── MacTwix/                 # Menubar SwiftUI app
├── MacTwixHelper/           # Root LaunchDaemon (XPC)
├── Shared/                  # Protocol + FixValues
├── Config/                  # xcconfig (Local.xcconfig is gitignored)
├── MacTwix.xcodeproj/
├── project.yml              # XcodeGen source of truth
├── scripts/                 # CLI reference backends
└── doc/
```

## CLI scripts (fallback)

```bash
sudo ./scripts/fix-wifi-tahoe.sh --install
sudo ./scripts/fix-wifi-tahoe.sh --auto
sudo ./scripts/fix-tcp-tahoe.sh --install
./scripts/fix-wifi-tahoe.sh --status
```

Prefer the app once the helper is installed.

## Agent debug API

While MacTwix is running, Cursor can observe live state:

```bash
curl -s http://127.0.0.1:18765/status
tail -f ~/Library/Logs/MacTwix/agent.log
```

See [doc/AGENT_API.md](doc/AGENT_API.md).

## Compatibility

Release builds are **universal** (`arm64` + `x86_64`) — one `.app` for Intel and Apple Silicon.

| Platform | AWDL | TCP | Auto |
|----------|------|-----|------|
| Intel Mac | Full | Full | Full |
| Apple Silicon | Full + AWDL watchdog | Full | Full |

On Apple Silicon (and some Tahoe Intel builds) macOS may re-enable `awdl0`; the helper watchdog re-disables it every ~2.5s while AWDL-off / Auto+torrent is active.

## License

MIT
