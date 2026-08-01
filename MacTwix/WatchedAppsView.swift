import AppKit
import SwiftUI

struct WatchedAppsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Watched Apps")
                .font(.title2.weight(.semibold))
            Text("When any selected app is running, Auto AWDL brings awdl0 down.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                model.applyTorrentsPreset()
            } label: {
                Label("Preset: Torrents Apps", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(model.busy)

            List {
                Section("Torrents catalog") {
                    ForEach(TriggerCatalog.torrentApps) { app in
                        Toggle(isOn: Binding(
                            get: { model.isTriggerSelected(app.bundleID) },
                            set: { _ in model.toggleTrigger(app.bundleID) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                Text(app.bundleID)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }

                if !customIDs.isEmpty {
                    Section("Custom") {
                        ForEach(customIDs, id: \.self) { bid in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(TriggerCatalog.displayName(for: bid))
                                    Text(bid)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    model.removeTrigger(bid)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            HStack {
                Button {
                    model.addAppViaPicker()
                } label: {
                    Label("Add app…", systemImage: "plus")
                }
                Spacer()
                Text("\(model.triggerBundleIDs.count) selected")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 420, minHeight: 480)
        .onAppear { AgentLog.event("watched-apps window appeared") }
    }

    private var customIDs: [String] {
        let known = Set(TriggerCatalog.torrentApps.map(\.bundleID))
        return model.triggerBundleIDs.filter { !known.contains($0) }
    }
}
