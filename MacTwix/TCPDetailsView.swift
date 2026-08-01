import SwiftUI

struct TCPDetailsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TCP Details")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("\(model.tcpOptimizedCount)/\(model.tcpTotal) optimized")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Apply Optimized") { model.setTCP(true) }
                    .disabled(model.busy || !model.connected)
                Button("Apple Default") { model.setTCP(false) }
                    .disabled(model.busy || !model.connected)
                Spacer()
                Button("Refresh") {
                    Task { await model.refreshFromHelper() }
                }
            }

            Table(model.tcpRows) {
                TableColumn("Key") { row in
                    Text(row.key)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 220)
                TableColumn("Current") { row in
                    Text(row.current)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(80)
                TableColumn("Fix") { row in
                    Text(row.fix)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(80)
                TableColumn("Apple") { row in
                    Text(row.apple)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(80)
                TableColumn("State") { row in
                    Text(row.stateLabel)
                        .foregroundStyle(row.stateColor)
                }
                .width(90)
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 420)
        .onAppear {
            AgentLog.event("tcp-details window appeared")
            Task { await model.refreshFromHelper() }
        }
    }
}
