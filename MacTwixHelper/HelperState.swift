import Foundation

final class HelperState {
    static let shared = HelperState()

    var tcpOptimized = false
    var awdlForcedDown = false
    var autoMode = false
    var applyTCPAtLogin = false
    var triggerBundleIDs: [String] = TriggerCatalog.defaultTriggerBundleIDs

    private struct Disk: Codable {
        var tcpOptimized: Bool
        var awdlForcedDown: Bool
        var autoMode: Bool
        var applyTCPAtLogin: Bool
        var triggerBundleIDs: [String]
    }

    private let url: URL = {
        let base = URL(fileURLWithPath: "/var/root/Library/Application Support/MacTwix", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("state.json")
    }()

    private init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Disk.self, from: data)
        else { return }
        tcpOptimized = decoded.tcpOptimized
        awdlForcedDown = decoded.awdlForcedDown
        autoMode = decoded.autoMode
        applyTCPAtLogin = decoded.applyTCPAtLogin
        triggerBundleIDs = decoded.triggerBundleIDs
    }

    func save() {
        let disk = Disk(
            tcpOptimized: tcpOptimized,
            awdlForcedDown: awdlForcedDown,
            autoMode: autoMode,
            applyTCPAtLogin: applyTCPAtLogin,
            triggerBundleIDs: triggerBundleIDs
        )
        guard let data = try? JSONEncoder().encode(disk) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func reset() {
        tcpOptimized = false
        awdlForcedDown = false
        autoMode = false
        applyTCPAtLogin = false
        triggerBundleIDs = FixValues.defaultTriggerBundleIDs
        try? FileManager.default.removeItem(at: url)
        let snap = URL(fileURLWithPath: "/var/root/Library/Application Support/MacTwix/tcp-snapshot.json")
        try? FileManager.default.removeItem(at: snap)
    }
}
