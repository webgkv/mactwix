import AppKit
import ServiceManagement
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var versionTapCount = 0

    var body: some View {
        Form {
            Section("Helper") {
                LabeledContent("Status", value: model.helperStatusText)
                LabeledContent("Connected", value: model.connected ? "yes" : "no")
                HStack {
                    Button("Install Helper") { model.installHelper() }
                        .disabled(model.busy || model.helperStatus == .enabled)
                    Button("Login Items…") { model.openLoginItems() }
                    Button("Uninstall Helper…", role: .destructive) {
                        model.uninstallEverything()
                    }
                    .disabled(model.busy || model.helperStatus == .notRegistered)
                }
            }

            Section("Startup") {
                Toggle("Apply TCP at Login", isOn: Binding(
                    get: { model.applyAtLogin },
                    set: { model.setApplyAtLogin($0) }
                ))
                .disabled(!model.connected)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .onTapGesture {
                            versionTapCount += 1
                            if versionTapCount >= 7 {
                                versionTapCount = 0
                                openWindow(id: "developer")
                                bringWindowToFront("Developer")
                            }
                        }
                }
                LabeledContent("Architecture", value: model.archLabel)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(minWidth: 480, minHeight: 300)
        .onAppear { AgentLog.event("preferences window appeared") }
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
