import Foundation
import Network

/// Localhost-only HTTP API so the Cursor agent can observe MacTwix live.
/// Bind: 127.0.0.1:18765
final class AgentDebugServer: @unchecked Sendable {
    static let shared = AgentDebugServer()

    private var listener: NWListener?
    private var modelProvider: (() -> [String: Any])?

    private init() {}

    func start(statusProvider: @escaping () -> [String: Any]) {
        modelProvider = statusProvider
        guard listener == nil else { return }

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: AgentLog.port)!)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    AgentLog.info("Agent API listening on http://127.0.0.1:\(AgentLog.port)")
                case .failed(let error):
                    AgentLog.error("Agent API failed: \(error)")
                default:
                    break
                }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener
        } catch {
            AgentLog.error("Agent API could not start: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64_000) { [weak self] data, _, _, error in
            guard let self, let data, error == nil,
                  let request = String(data: data, encoding: .utf8)
            else {
                connection.cancel()
                return
            }
            let response = self.route(request)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func route(_ request: String) -> Data {
        let first = request.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = first.split(separator: " ")
        let method = parts.count > 0 ? String(parts[0]) : "GET"
        let pathQuery = parts.count > 1 ? String(parts[1]) : "/"
        let path = pathQuery.split(separator: "?").first.map(String.init) ?? "/"
        let query = pathQuery.split(separator: "?", maxSplits: 1).count > 1
            ? String(pathQuery.split(separator: "?", maxSplits: 1)[1])
            : ""

        if method == "GET" && (path == "/" || path == "/health") {
            return jsonResponse(200, ["ok": true, "service": "mactwix-agent", "port": Int(AgentLog.port)])
        }
        if method == "GET" && path == "/status" {
            let status = modelProvider?() ?? ["error": "no provider"]
            return jsonResponse(200, status)
        }
        if method == "GET" && path == "/logs" {
            let limit = Int(queryValue(query, key: "limit") ?? "100") ?? 100
            return jsonResponse(200, [
                "lines": AgentLog.recent(limit: limit),
                "logFile": AgentLog.logURL.path,
                "statusFile": AgentLog.statusURL.path,
            ])
        }
        if method == "GET" && path == "/paths" {
            return jsonResponse(200, [
                "statusFile": AgentLog.statusURL.path,
                "logFile": AgentLog.logURL.path,
                "baseURL": "http://127.0.0.1:\(AgentLog.port)",
            ])
        }
        return jsonResponse(404, ["error": "not found", "endpoints": ["/health", "/status", "/logs", "/paths"]])
    }

    private func queryValue(_ query: String, key: String) -> String? {
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, String(kv[0]) == key {
                return String(kv[1])
            }
        }
        return nil
    }

    private func jsonResponse(_ code: Int, _ object: [String: Any]) -> Data {
        let body: Data
        if JSONSerialization.isValidJSONObject(object),
           let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
            body = data
        } else {
            body = Data("{\"error\":\"encode\"}".utf8)
        }
        let status = code == 200 ? "OK" : "ERR"
        let header = "HTTP/1.1 \(code) \(status)\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        var out = Data(header.utf8)
        out.append(body)
        return out
    }
}
