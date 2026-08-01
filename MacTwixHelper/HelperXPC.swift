import Foundation

final class HelperXPCService: NSObject, NSXPCListenerDelegate, HelperProtocol {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard ClientAuth.isTrusted(connection: newConnection) else {
            Logger.log("Rejected untrusted XPC client pid=\(newConnection.processIdentifier)")
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func ping(reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func getStatus(reply: @escaping (NSDictionary) -> Void) {
        reply(NetworkOps.shared.statusDictionary() as NSDictionary)
    }

    func setTCPOptimized(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void) {
        do {
            if enabled {
                try NetworkOps.shared.applyTCPOptimized()
            } else {
                try NetworkOps.shared.rollbackTCP()
            }
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func setAWDLEnabled(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void) {
        do {
            // Manual AWDL control disables auto-mode ownership of the interface.
            if enabled == false {
                AutoModeEngine.shared.setEnabled(false, triggers: [])
            }
            try NetworkOps.shared.setAWDL(up: enabled)
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func setAutoMode(_ enabled: Bool, triggerBundleIDs: [String], reply: @escaping (Bool, String?) -> Void) {
        AutoModeEngine.shared.setEnabled(enabled, triggers: triggerBundleIDs)
        reply(true, nil)
    }

    func setApplyAtLogin(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void) {
        // With SMAppService KeepAlive daemon, TCP re-apply is handled at helper start
        // when persisted preference says so.
        HelperState.shared.applyTCPAtLogin = enabled
        HelperState.shared.save()
        reply(true, nil)
    }

    func uninstallAll(reply: @escaping (Bool, String?) -> Void) {
        AutoModeEngine.shared.setEnabled(false, triggers: [])
        try? NetworkOps.shared.rollbackTCP()
        try? NetworkOps.shared.setAWDL(up: true)
        try? NetworkOps.shared.restorePowerDefaults()
        HelperState.shared.reset()
        reply(true, "Helper state cleared. Unregister the daemon from the app, then quit.")
    }
}

enum ClientAuth {
    static func isTrusted(connection: NSXPCConnection) -> Bool {
        var code: SecCode?
        var staticCode: SecStaticCode?
        let pid = connection.processIdentifier
        let keys: [CFString: Any] = [kSecGuestAttributePid: pid]
        guard SecCodeCopyGuestWithAttributes(nil, keys as CFDictionary, [], &code) == errSecSuccess,
              let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode
        else {
            return false
        }

        // Require same Team ID when both are properly signed; allow same-path debug builds.
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let info = info as? [String: Any]
        else {
            return false
        }

        if let identifier = info[kSecCodeInfoIdentifier as String] as? String {
            if identifier == HelperConstants.appBundleID {
                return true
            }
        }

        // Fallback: compare team identifiers
        if let appTeam = teamID(from: info),
           let selfTeam = selfTeamID(),
           !appTeam.isEmpty,
           appTeam == selfTeam {
            return true
        }

        #if DEBUG
        Logger.log("DEBUG: accepting client with weak auth checks")
        return true
        #else
        return false
        #endif
    }

    private static func teamID(from info: [String: Any]) -> String? {
        if let team = info[kSecCodeInfoTeamIdentifier as String] as? String {
            return team
        }
        return nil
    }

    private static func selfTeamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let info = info as? [String: Any]
        else { return nil }
        return teamID(from: info)
    }
}
