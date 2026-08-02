import AppKit
import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 8)

            if model.helperMissing {
                helperWarning
                Divider().padding(.vertical, 8)
            }

            if model.tcpBannerVisible {
                tcpWarning
                Divider().padding(.vertical, 8)
            }

            if model.updateAvailable != nil {
                updateBanner
                Divider().padding(.vertical, 8)
            }

            statusBlock
            Divider().padding(.vertical, 8)
            quickToggles
            Divider().padding(.vertical, 8)
            secondaryButtons
            Divider().padding(.vertical, 8)
            footer
        }
        .padding(14)
        .frame(width: 300)
        .onAppear {
            Task { await model.refreshFromHelper() }
            AgentLog.event("preview opened")
        }
    }

    private var header: some View {
        HStack {
            Text("MacTwix")
                .font(.headline)
            Spacer()
            if model.smartAWDLActive {
                Text("Smart")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            Text("v1.0.1")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var helperWarning: some View {
        Button {
            openWindow(id: "preferences")
            bringWindowToFront("Preferences")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Helper not installed")
                        .font(.callout.weight(.medium))
                    Text("Tap to open Preferences and install")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var tcpWarning: some View {
        Button {
            openWindow(id: "tcp-details")
            bringWindowToFront("TCP Details")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TCP not optimized")
                        .font(.callout.weight(.medium))
                    Text("Tap to open TCP Details")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var updateBanner: some View {
        Button {
            openWindow(id: "preferences")
            bringWindowToFront("Preferences")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update available v\(model.updateAvailable ?? "")")
                        .font(.callout.weight(.medium))
                    Text("Tap to open Preferences")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var statusBlock: some View {
        VStack(spacing: 6) {
            statusRow("Helper", model.helperStatusText, model.connected ? .green : .secondary)
            statusRow("AWDL", model.awdlStatusText, model.smartAWDLActive ? .orange : .primary)
            statusRow("TCP", model.tcpStatusText, model.tcpOptimized ? .green : .primary)
            statusRow("Auto", model.autoStatusText, model.autoMode ? .blue : .secondary)
        }
    }

    private func statusRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }

    private var quickToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { model.tcpOptimized },
                set: { model.setTCP($0) }
            )) {
                Text("TCP Optimized")
            }
            .tint(.blue)
            .disabled(model.busy || !model.connected)

            Toggle(isOn: Binding(
                get: { model.awdlDisabled },
                set: { model.setAWDLDisabled($0) }
            )) {
                Text("AWDL Disabled")
            }
            .tint(.blue)
            .disabled(model.busy || !model.connected || model.autoMode)

            Toggle(isOn: Binding(
                get: { model.autoMode },
                set: { model.setAuto($0) }
            )) {
                Text("Auto AWDL")
            }
            .tint(.blue)
            .disabled(model.busy || !model.connected)
        }
    }

    private var secondaryButtons: some View {
        VStack(spacing: 6) {
            Button {
                openWindow(id: "watched-apps")
                bringWindowToFront("Watched Apps")
            } label: {
                Text("Watched Apps…")
                    .frame(maxWidth: .infinity)
            }

            Button {
                openWindow(id: "tcp-details")
                bringWindowToFront("TCP Details")
            } label: {
                Text("TCP Details…")
                    .frame(maxWidth: .infinity)
            }

            Button {
                openWindow(id: "preferences")
                bringWindowToFront("Preferences")
            } label: {
                Text("Preferences…")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private var footer: some View {
        HStack {
            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Quit") {
                AgentLog.event("quit")
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func bringWindowToFront(_ title: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApplication.shared.windows where window.title == title {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }
}
