import Foundation

final class HelperClient {
    private var connection: NSXPCConnection?

    private func proxy() -> HelperProtocol? {
        if connection == nil {
            let conn = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
            conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
            conn.invalidationHandler = { [weak self] in
                self?.connection = nil
            }
            conn.interruptionHandler = { [weak self] in
                self?.connection = nil
            }
            conn.resume()
            connection = conn
        }
        return connection?.remoteObjectProxyWithErrorHandler { error in
            NSLog("MacTwix XPC error: %@", error.localizedDescription)
        } as? HelperProtocol
    }

    func pingAsync() async -> Bool {
        await withCheckedContinuation { cont in
            guard let proxy = proxy() else {
                cont.resume(returning: false)
                return
            }
            proxy.ping { ok in
                cont.resume(returning: ok)
            }
        }
    }

    func getStatusAsync() async -> [String: Any]? {
        await withCheckedContinuation { cont in
            guard let proxy = proxy() else {
                cont.resume(returning: nil)
                return
            }
            proxy.getStatus { dict in
                var typed: [String: Any] = [:]
                dict.forEach { key, value in
                    if let key = key as? String {
                        typed[key] = value
                    }
                }
                cont.resume(returning: typed)
            }
        }
    }

    func setTCPOptimized(_ enabled: Bool, completion: @escaping (Bool, String?) -> Void) {
        guard let proxy = proxy() else {
            completion(false, "Helper not connected")
            return
        }
        proxy.setTCPOptimized(enabled, reply: completion)
    }

    func setAWDLEnabled(_ enabled: Bool, completion: @escaping (Bool, String?) -> Void) {
        guard let proxy = proxy() else {
            completion(false, "Helper not connected")
            return
        }
        proxy.setAWDLEnabled(enabled, reply: completion)
    }

    func setAutoMode(_ enabled: Bool, triggers: [String], completion: @escaping (Bool, String?) -> Void) {
        guard let proxy = proxy() else {
            completion(false, "Helper not connected")
            return
        }
        proxy.setAutoMode(enabled, triggerBundleIDs: triggers, reply: completion)
    }

    func setApplyAtLogin(_ enabled: Bool, completion: @escaping (Bool, String?) -> Void) {
        guard let proxy = proxy() else {
            completion(false, "Helper not connected")
            return
        }
        proxy.setApplyAtLogin(enabled, reply: completion)
    }

    func uninstallAll(completion: @escaping (Bool, String?) -> Void) {
        guard let proxy = proxy() else {
            completion(true, "Helper was not running")
            return
        }
        proxy.uninstallAll(reply: completion)
    }
}
