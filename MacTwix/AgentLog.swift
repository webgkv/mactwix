import Foundation

/// Ring-buffer + file log for the Cursor agent debug API.
enum AgentLog {
    static let port: UInt16 = 18765
    static let statusURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/MacTwix/agent-status.json")
    static let logURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/MacTwix/agent.log")

    private static let queue = DispatchQueue(label: "com.webgkv.mactwix.agentlog")
    private static var lines: [String] = []
    private static let maxLines = 500

    static func ensureDir() {
        let dir = statusURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    static func info(_ message: String) { append(level: "info", message) }
    static func warn(_ message: String) { append(level: "warn", message) }
    static func error(_ message: String) { append(level: "error", message) }
    static func event(_ message: String) { append(level: "event", message) }

    static func append(level: String, _ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "\(ts) [\(level)] \(message)"
        queue.async {
            ensureDir()
            lines.append(line)
            if lines.count > maxLines {
                lines.removeFirst(lines.count - maxLines)
            }
            if let data = (line + "\n").data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logURL.path) {
                    if let handle = try? FileHandle(forWritingTo: logURL) {
                        defer { try? handle.close() }
                        try? handle.seekToEnd()
                        try? handle.write(contentsOf: data)
                    }
                } else {
                    try? data.write(to: logURL)
                }
            }
        }
        NSLog("%@", "MacTwixAgent: \(message)")
    }

    static func recent(limit: Int = 100) -> [String] {
        queue.sync {
            Array(lines.suffix(limit))
        }
    }

    static func writeStatusJSON(_ object: [String: Any]) {
        queue.async {
            ensureDir()
            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            else { return }
            try? data.write(to: statusURL, options: .atomic)
        }
    }
}
