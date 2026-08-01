import Foundation

/// Re-asserts AWDL down while a policy requires it.
/// Needed on Apple Silicon (and some Intel Tahoe builds) where macOS
/// periodically brings `awdl0` back up on its own.
final class AWDLWatchdog {
    static let shared = AWDLWatchdog()

    private var timer: Timer?
    private let interval: TimeInterval = 2.5

    private init() {}

    /// Start (or restart) the watchdog. Safe to call repeatedly.
    func start() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(t, forMode: .common)
        timer = t
        tick()
        Logger.log("AWDL watchdog started (interval \(interval)s)")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let shouldKeepDown: Bool
        if AutoModeEngine.shared.isEnabled {
            shouldKeepDown = AutoModeEngine.shared.isTriggerActive
        } else {
            shouldKeepDown = HelperState.shared.awdlForcedDown
        }

        guard shouldKeepDown else { return }
        guard NetworkOps.shared.awdlIsUp() else { return }

        do {
            try NetworkOps.shared.reassertAWDLDown()
            Logger.log("AWDL watchdog: re-disabled awdl0 (OS brought it back)")
        } catch {
            Logger.log("AWDL watchdog error: \(error.localizedDescription)")
        }
    }
}
