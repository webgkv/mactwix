import AppKit
import Foundation

/// Watches trigger apps and toggles AWDL. Runs inside the root helper so it
/// keeps working after the menubar app quits.
final class AutoModeEngine {
    static let shared = AutoModeEngine()

    private(set) var isEnabled = false
    /// Latest poll result — used by AWDLWatchdog while Auto is on.
    private(set) var isTriggerActive = false
    private var triggers: Set<String> = []
    private var timer: Timer?
    private var lastTorrentActive: Bool?

    private init() {}

    func start() {
        HelperState.shared.load()
        if HelperState.shared.autoMode {
            setEnabled(true, triggers: HelperState.shared.triggerBundleIDs)
        }
        NetworkOps.shared.reapplyPersistedPolicy()
        // Always run watchdog: covers forced AWDL-off and Apple Silicon re-enable.
        AWDLWatchdog.shared.start()
    }

    func setEnabled(_ enabled: Bool, triggers: [String]) {
        isEnabled = enabled
        self.triggers = Set(triggers.isEmpty ? FixValues.defaultTriggerBundleIDs : triggers)
        HelperState.shared.autoMode = enabled
        HelperState.shared.triggerBundleIDs = Array(self.triggers)
        HelperState.shared.save()

        timer?.invalidate()
        timer = nil
        lastTorrentActive = nil
        isTriggerActive = false

        guard enabled else {
            AWDLWatchdog.shared.start()
            return
        }

        let t = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(t, forMode: .common)
        timer = t
        AWDLWatchdog.shared.start()
        tick()
    }

    private func tick() {
        let active = isAnyTriggerRunning()
        isTriggerActive = active
        if lastTorrentActive == active { return }
        lastTorrentActive = active
        do {
            if active {
                try NetworkOps.shared.setAWDL(up: false)
                Logger.log("Auto: trigger app running → AWDL down")
            } else {
                try NetworkOps.shared.setAWDL(up: true)
                Logger.log("Auto: no trigger apps → AWDL up")
            }
        } catch {
            Logger.log("Auto tick error: \(error.localizedDescription)")
        }
    }

    private func isAnyTriggerRunning() -> Bool {
        // Prefer lsappinfo: root LaunchDaemon often cannot see the console
        // user's apps via NSWorkspace (Intel and Apple Silicon alike).
        if isAnyTriggerRunningViaLsappinfo() {
            return true
        }
        let wsApps = NSWorkspace.shared.runningApplications
        return wsApps.contains { app in
            guard let bid = app.bundleIdentifier else { return false }
            return triggers.contains(bid)
        }
    }

    private func isAnyTriggerRunningViaLsappinfo() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lsappinfo")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            return false
        }
        for bid in triggers {
            if output.contains(bid) {
                return true
            }
        }
        return false
    }
}
