import Foundation

enum HelperConstants {
    static let machServiceName = "com.webgkv.mactwix.helper"
    static let helperPlistName = "com.webgkv.mactwix.helper.plist"
    static let appBundleID = "com.webgkv.mactwix"
    static let helperBundleID = "com.webgkv.mactwix.helper"
}

@objc protocol HelperProtocol {
    func getStatus(reply: @escaping (NSDictionary) -> Void)
    func setTCPOptimized(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void)
    func setAWDLEnabled(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void)
    func setAutoMode(_ enabled: Bool, triggerBundleIDs: [String], reply: @escaping (Bool, String?) -> Void)
    func setApplyAtLogin(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void)
    func uninstallAll(reply: @escaping (Bool, String?) -> Void)
    func ping(reply: @escaping (Bool) -> Void)
}
