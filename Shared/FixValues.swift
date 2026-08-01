import Foundation

/// Canonical TCP / power values from `doc/FIXES.md`.
enum FixValues {
    struct SysctlSetting: Sendable {
        let key: String
        let optimized: String
        let appleDefault: String
    }

    static let tcpSettings: [SysctlSetting] = [
        .init(key: "net.inet.tcp.tso", optimized: "0", appleDefault: "1"),
        .init(key: "net.inet.tcp.ecn_initiate_out", optimized: "0", appleDefault: "2"),
        .init(key: "net.inet.tcp.ecn_setup_percentage", optimized: "0", appleDefault: "100"),
        .init(key: "net.inet.tcp.mssdflt", optimized: "1460", appleDefault: "512"),
        .init(key: "net.inet.tcp.delayed_ack", optimized: "0", appleDefault: "3"),
        .init(key: "net.inet.tcp.win_scale_factor", optimized: "8", appleDefault: "3"),
        .init(key: "net.inet.tcp.autorcvbufmax", optimized: "33554432", appleDefault: "4194304"),
        .init(key: "net.inet.tcp.autosndbufmax", optimized: "33554432", appleDefault: "4194304"),
        .init(key: "net.inet.tcp.sendspace", optimized: "262144", appleDefault: "131072"),
        .init(key: "net.inet.tcp.recvspace", optimized: "262144", appleDefault: "131072"),
        .init(key: "net.inet.tcp.recv_allowed_iaj", optimized: "100", appleDefault: "5"),
        .init(key: "net.inet.tcp.acc_iaj_react_limit", optimized: "10000", appleDefault: "200"),
        .init(key: "net.inet.tcp.recv_throttle_minwin", optimized: "4194304", appleDefault: "0"),
        .init(key: "net.inet.tcp.local_slowstart_flightsize", optimized: "20", appleDefault: "8"),
        .init(key: "net.inet.tcp.cubic_tcp_friendliness", optimized: "1", appleDefault: "0"),
        .init(key: "net.inet.tcp.cubic_fast_convergence", optimized: "1", appleDefault: "0"),
        .init(key: "net.inet.tcp.cubic_use_minrtt", optimized: "1", appleDefault: "0"),
    ]

    /// Default torrent / multi-connection apps that trigger Auto AWDL.
    /// Prefer `TriggerCatalog.defaultTriggerBundleIDs` in new code.
    static let defaultTriggerBundleIDs: [String] = TriggerCatalog.defaultTriggerBundleIDs
}
