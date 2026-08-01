import Foundation

final class NetworkOps {
    static let shared = NetworkOps()

    private let stateURL: URL = {
        let base = URL(fileURLWithPath: "/var/root/Library/Application Support/MacTwix", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("tcp-snapshot.json")
    }()

    func statusDictionary() -> [String: Any] {
        var tcp: [String: String] = [:]
        var optimizedCount = 0
        for setting in FixValues.tcpSettings {
            let current = sysctlRead(setting.key) ?? "?"
            tcp[setting.key] = current
            if current == setting.optimized { optimizedCount += 1 }
        }
        return [
            "awdlUp": awdlIsUp(),
            "tcpOptimizedCount": optimizedCount,
            "tcpTotal": FixValues.tcpSettings.count,
            "tcpFullyOptimized": optimizedCount == FixValues.tcpSettings.count,
            "autoMode": AutoModeEngine.shared.isEnabled,
            "smartAWDLActive": AutoModeEngine.shared.isEnabled && AutoModeEngine.shared.isTriggerActive,
            "triggerBundleIDs": HelperState.shared.triggerBundleIDs,
            "applyTCPAtLogin": HelperState.shared.applyTCPAtLogin,
            "uid": getuid(),
            "arch": hostArchitecture(),
            "tcp": tcp,
        ]
    }

    func applyTCPOptimized() throws {
        snapshotTCPIfNeeded()
        try apply(values: FixValues.tcpSettings.map { ($0.key, $0.optimized) })
        HelperState.shared.tcpOptimized = true
        HelperState.shared.save()
    }

    func rollbackTCP() throws {
        if let snapshot = loadSnapshot() {
            try apply(values: snapshot.map { ($0.key, $0.value) })
        } else {
            try apply(values: FixValues.tcpSettings.map { ($0.key, $0.appleDefault) })
        }
        HelperState.shared.tcpOptimized = false
        HelperState.shared.save()
    }

    func setAWDL(up: Bool) throws {
        try applyAWDL(up: up)
        HelperState.shared.awdlForcedDown = !up
        HelperState.shared.save()
    }

    /// ifconfig only — used by the watchdog so we do not rewrite state.json every few seconds.
    func reassertAWDLDown() throws {
        try applyAWDL(up: false)
    }

    func awdlIsUp() -> Bool {
        let result = run("/sbin/ifconfig", ["awdl0"])
        return result.stdout.contains("status: active") || result.stdout.contains("<UP,")
    }

    /// CPU architecture of this helper process (`arm64` / `x86_64`).
    func hostArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    func applyPowerTweaks() throws {
        _ = run("/usr/bin/pmset", ["-a", "womp", "0"])
        _ = run("/usr/bin/pmset", ["-a", "tcpkeepalive", "0"])
    }

    func restorePowerDefaults() throws {
        _ = run("/usr/bin/pmset", ["-a", "womp", "1"])
        _ = run("/usr/bin/pmset", ["-a", "tcpkeepalive", "1"])
    }

    func reapplyPersistedPolicy() {
        if HelperState.shared.tcpOptimized && HelperState.shared.applyTCPAtLogin {
            try? applyTCPOptimized()
        }
        if HelperState.shared.awdlForcedDown && !AutoModeEngine.shared.isEnabled {
            try? setAWDL(up: false)
        }
    }

    // MARK: - Private

    private func applyAWDL(up: Bool) throws {
        let arg = up ? "up" : "down"
        let result = run("/sbin/ifconfig", ["awdl0", arg])
        if result.status != 0 {
            throw OpsError.message(result.stderr.isEmpty ? "ifconfig awdl0 \(arg) failed" : result.stderr)
        }
    }

    private func snapshotTCPIfNeeded() {
        guard !FileManager.default.fileExists(atPath: stateURL.path) else { return }
        var snap: [String: String] = [:]
        for setting in FixValues.tcpSettings {
            snap[setting.key] = sysctlRead(setting.key) ?? setting.appleDefault
        }
        if let data = try? JSONSerialization.data(withJSONObject: snap, options: [.prettyPrinted]) {
            try? data.write(to: stateURL)
        }
    }

    private func loadSnapshot() -> [String: String]? {
        guard let data = try? Data(contentsOf: stateURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }
        return obj
    }

    private func apply(values: [(String, String)]) throws {
        var args: [String] = ["-w"]
        for (key, value) in values {
            args.append("\(key)=\(value)")
        }
        let result = run("/usr/sbin/sysctl", args)
        if result.status != 0 {
            throw OpsError.message(result.stderr.isEmpty ? "sysctl failed" : result.stderr)
        }
    }

    private func sysctlRead(_ key: String) -> String? {
        let result = run("/usr/sbin/sysctl", ["-n", key])
        guard result.status == 0 else { return nil }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(_ launchPath: String, _ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, "", error.localizedDescription)
        }
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }
}

enum OpsError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let s): return s
        }
    }
}
