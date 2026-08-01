import SwiftUI

struct DeveloperView: View {
    @EnvironmentObject private var model: AppModel
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(.orange)
                Text("Developer / Agent API")
                    .font(.title2.weight(.semibold))
            }

            Text("Use these endpoints to monitor MacTwix from Cursor or any HTTP client.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("Endpoints") {
                VStack(alignment: .leading, spacing: 8) {
                    devRow("Base URL", "http://127.0.0.1:\(AgentLog.port)")
                    devRow("Health", "http://127.0.0.1:\(AgentLog.port)/health")
                    devRow("Status", "http://127.0.0.1:\(AgentLog.port)/status")
                    devRow("Logs", "http://127.0.0.1:\(AgentLog.port)/logs?limit=50")
                    devRow("Paths", "http://127.0.0.1:\(AgentLog.port)/paths")
                }
                .padding(4)
            }

            GroupBox("File paths") {
                VStack(alignment: .leading, spacing: 8) {
                    devRow("Status JSON", AgentLog.statusURL.path)
                    devRow("Log file", AgentLog.logURL.path)
                }
                .padding(4)
            }

            HStack {
                Button {
                    copyToClipboard()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Label(copied ? "Copied!" : "Copy All", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(copied ? .green : .accentColor)

                Spacer()

                Text("Localhost only · no auth required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 320)
        .onAppear { AgentLog.event("developer window appeared") }
    }

    private func devRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func copyToClipboard() {
        let text = """
        MacTwix Agent API
        =================
        Base URL: http://127.0.0.1:\(AgentLog.port)
        Health:   http://127.0.0.1:\(AgentLog.port)/health
        Status:   http://127.0.0.1:\(AgentLog.port)/status
        Logs:     http://127.0.0.1:\(AgentLog.port)/logs?limit=50
        Paths:    http://127.0.0.1:\(AgentLog.port)/paths

        Status JSON: \(AgentLog.statusURL.path)
        Log file:    \(AgentLog.logURL.path)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        AgentLog.event("developer: copied API info")
    }
}
