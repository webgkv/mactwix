import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct TCPRow: Identifiable {
    let id: String
    let key: String
    let current: String
    let fix: String
    let apple: String

    var stateLabel: String {
        if current == fix { return "optimized" }
        if current == apple { return "apple" }
        return "custom"
    }

    var stateColor: Color {
        switch stateLabel {
        case "optimized": return .green
        case "apple": return .secondary
        default: return .orange
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var helperStatus: SMAppService.Status = .notRegistered
    @Published var connected = false
    @Published var statusMessage = ""
    @Published var busy = false

    @Published var tcpOptimized = false
    @Published var awdlDisabled = false
    @Published var autoMode = false
    @Published var applyAtLogin = false
    @Published var tcpOptimizedCount = 0
    @Published var tcpTotal = FixValues.tcpSettings.count
    @Published var smartAWDLActive = false
    @Published var triggerBundleIDs: [String] = TriggerCatalog.defaultTriggerBundleIDs
    @Published var tcpValues: [String: String] = [:]
    @Published var archLabel: String = AppModel.detectMachineInfo()

    private static func detectMachineInfo() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)

        size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelStr = String(cString: model)

        let arch: String
        #if arch(arm64)
        arch = "arm64"
        #elseif arch(x86_64)
        arch = "x86_64"
        #else
        arch = "unknown"
        #endif

        let marketingName = AppModel.marketingName(for: modelStr)
        if let name = marketingName {
            return "\(name) · \(arch)"
        }
        return "\(modelStr) · \(arch)"
    }

    private static func marketingName(for modelID: String) -> String? {
        let map: [String: String] = [
            "Mac14,2": "MacBook Air M2 (2022)",
            "Mac14,7": "MacBook Pro 13\" M2 (2022)",
            "Mac14,5": "MacBook Pro 14\" M2 Pro/Max",
            "Mac14,6": "MacBook Pro 16\" M2 Pro/Max",
            "Mac14,9": "MacBook Pro 14\" M2 Pro/Max",
            "Mac14,10": "MacBook Pro 16\" M2 Pro/Max",
            "Mac14,15": "MacBook Air 15\" M2 (2023)",
            "Mac15,3": "MacBook Pro 14\" M3",
            "Mac15,6": "MacBook Pro 14\" M3 Pro/Max",
            "Mac15,7": "MacBook Pro 16\" M3 Pro/Max",
            "Mac15,8": "MacBook Pro 14\" M3 Pro/Max",
            "Mac15,9": "MacBook Pro 16\" M3 Pro/Max",
            "Mac15,10": "MacBook Pro 14\" M3 Pro/Max",
            "Mac15,11": "MacBook Pro 16\" M3 Pro/Max",
            "Mac15,12": "MacBook Air 13\" M3 (2024)",
            "Mac15,13": "MacBook Air 15\" M3 (2024)",
            "Mac16,1": "MacBook Pro 14\" M4",
            "Mac16,2": "MacBook Pro 14\" M4 Pro/Max",
            "Mac16,3": "MacBook Pro 14\" M4 Pro/Max",
            "Mac16,5": "MacBook Pro 16\" M4 Pro/Max",
            "Mac16,6": "MacBook Pro 16\" M4 Pro/Max",
            "Mac16,7": "MacBook Pro 14\" M4 Pro/Max",
            "Mac16,8": "MacBook Air 13\" M4 (2025)",
            "Mac16,9": "MacBook Air 15\" M4 (2025)",
            "Mac16,10": "MacBook Air 13\" M4",
            "Mac16,11": "MacBook Air 15\" M4",
            "Mac14,3": "Mac mini M2 (2023)",
            "Mac14,12": "Mac mini M2 Pro (2023)",
            "Mac14,13": "Mac Studio M2 Max (2023)",
            "Mac14,14": "Mac Studio M2 Ultra (2023)",
            "Mac14,8": "Mac Pro M2 Ultra (2023)",
            "Mac15,4": "iMac M3 (2023)",
            "Mac15,5": "iMac M3 (2023)",
            "Mac16,12": "Mac mini M4 (2024)",
            "Mac16,13": "Mac mini M4 Pro (2024)",
            "MacBookPro18,1": "MacBook Pro 16\" M1 Pro/Max",
            "MacBookPro18,2": "MacBook Pro 16\" M1 Pro/Max",
            "MacBookPro18,3": "MacBook Pro 14\" M1 Pro/Max",
            "MacBookPro18,4": "MacBook Pro 14\" M1 Pro/Max",
            "MacBookPro17,1": "MacBook Pro 13\" M1 (2020)",
            "MacBookAir10,1": "MacBook Air M1 (2020)",
            "MacBookPro16,1": "MacBook Pro 16\" i9 (2019)",
            "MacBookPro16,2": "MacBook Pro 13\" (2020)",
            "MacBookPro16,3": "MacBook Pro 13\" (2020)",
            "MacBookPro16,4": "MacBook Pro 16\" i9 (2019)",
            "Macmini9,1": "Mac mini M1 (2020)",
            "iMac21,1": "iMac 24\" M1 (2021)",
            "iMac21,2": "iMac 24\" M1 (2021)",
        ]
        return map[modelID]
    }

    private let client = HelperClient()
    private var refreshTask: Task<Void, Never>?
    private let triggersDefaultsKey = "triggerBundleIDs"

    @Published var showHelperInstallPrompt = false

    var helperMissing: Bool {
        helperStatus != .enabled
    }

    init() {
        if let saved = UserDefaults.standard.array(forKey: triggersDefaultsKey) as? [String], !saved.isEmpty {
            triggerBundleIDs = saved
        }
        AgentLog.info("AppModel init")
        AgentDebugServer.shared.start { [weak self] in
            guard let self else { return ["error": "no model"] }
            self.snapshotLock.lock()
            defer { self.snapshotLock.unlock() }
            return self.cachedSnapshot.isEmpty ? ["error": "starting"] : self.cachedSnapshot
        }
        refreshHelperStatus()
        refreshTask = Task {
            while !Task.isCancelled {
                await refreshFromHelper()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private var cachedSnapshot: [String: Any] = [:]
    private let snapshotLock = NSLock()

    deinit {
        refreshTask?.cancel()
    }

    var trayImageName: String {
        if smartAWDLActive || autoMode { return "TrayIconAuto" }
        return "TrayIcon"
    }

    var trayAccessibilityLabel: String {
        if smartAWDLActive { return "MacTwix — Smart AWDL off" }
        if autoMode { return "MacTwix — Auto AWDL armed" }
        return "MacTwix"
    }

    var helperStatusText: String {
        switch helperStatus {
        case .enabled: return connected ? "Connected" : "Enabled"
        case .requiresApproval: return "Needs approval"
        case .notFound: return "Not found"
        case .notRegistered: return "Not installed"
        @unknown default: return "Unknown"
        }
    }

    var awdlStatusText: String {
        if smartAWDLActive { return "DOWN · Smart" }
        if awdlDisabled { return "DOWN" }
        return "UP"
    }

    var tcpStatusText: String {
        "\(tcpOptimizedCount)/\(tcpTotal)" + (tcpOptimized ? " optimized" : "")
    }

    var autoStatusText: String {
        if smartAWDLActive { return "Active now" }
        if autoMode { return "Armed" }
        return "Off"
    }

    var tcpRows: [TCPRow] {
        FixValues.tcpSettings.map { setting in
            TCPRow(
                id: setting.key,
                key: setting.key,
                current: tcpValues[setting.key] ?? "?",
                fix: setting.optimized,
                apple: setting.appleDefault
            )
        }
    }

    func refreshHelperStatus() {
        helperStatus = SMAppService.daemon(plistName: HelperConstants.helperPlistName).status
    }

    func installHelper() {
        busy = true
        AgentLog.event("installHelper")
        do {
            try SMAppService.daemon(plistName: HelperConstants.helperPlistName).register()
            statusMessage = ""
            AgentLog.info("helper register OK")
        } catch {
            statusMessage = "Register failed: \(error.localizedDescription)"
            AgentLog.error("helper register failed: \(error.localizedDescription)")
        }
        registerAppAtLogin()
        refreshHelperStatus()
        busy = false
        publishSnapshot()
    }

    func openLoginItems() {
        AgentLog.event("openLoginItems")
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func registerAppAtLogin() {
        AgentLog.event("registerAppAtLogin")
        do {
            try SMAppService.mainApp.register()
            statusMessage = ""
            AgentLog.info("app login item registered")
        } catch {
            statusMessage = "Login item: \(error.localizedDescription)"
            AgentLog.error("app login item failed: \(error.localizedDescription)")
        }
    }

    func uninstallEverything() {
        busy = true
        statusMessage = "Uninstalling…"
        AgentLog.event("uninstallEverything")
        client.uninstallAll { [weak self] ok, message in
            Task { @MainActor in
                guard let self else { return }
                do {
                    try SMAppService.daemon(plistName: HelperConstants.helperPlistName).unregister()
                } catch {
                    self.statusMessage = "Unregister: \(error.localizedDescription)"
                    AgentLog.error(self.statusMessage)
                    self.busy = false
                    self.refreshHelperStatus()
                    self.publishSnapshot()
                    return
                }
                self.connected = false
                self.tcpOptimized = false
                self.awdlDisabled = false
                self.autoMode = false
                self.smartAWDLActive = false
                self.statusMessage = ok ? "Uninstalled." : (message ?? "Uninstall failed")
                AgentLog.info(self.statusMessage)
                self.refreshHelperStatus()
                self.busy = false
                self.publishSnapshot()
            }
        }
    }

    func setTCP(_ enabled: Bool) {
        busy = true
        AgentLog.event("setTCP \(enabled)")
        client.setTCPOptimized(enabled) { [weak self] ok, err in
            Task { @MainActor in
                self?.busy = false
                self?.statusMessage = ok ? (enabled ? "TCP optimized" : "TCP restored") : (err ?? "Failed")
                AgentLog.info(self?.statusMessage ?? "")
                await self?.refreshFromHelper()
            }
        }
    }

    func setAWDLDisabled(_ disabled: Bool) {
        busy = true
        AgentLog.event("setAWDLDisabled \(disabled)")
        client.setAWDLEnabled(!disabled) { [weak self] ok, err in
            Task { @MainActor in
                self?.busy = false
                self?.statusMessage = ok
                    ? (disabled ? "AWDL disabled" : "AWDL enabled")
                    : (err ?? "Failed")
                AgentLog.info(self?.statusMessage ?? "")
                await self?.refreshFromHelper()
            }
        }
    }

    func setAuto(_ enabled: Bool) {
        busy = true
        let triggers = triggerBundleIDs.isEmpty ? TriggerCatalog.defaultTriggerBundleIDs : triggerBundleIDs
        AgentLog.event("setAuto \(enabled) triggers=\(triggers.count)")
        client.setAutoMode(enabled, triggers: triggers) { [weak self] ok, err in
            Task { @MainActor in
                self?.busy = false
                self?.statusMessage = ok
                    ? (enabled ? "Auto AWDL on" : "Auto AWDL off")
                    : (err ?? "Failed")
                AgentLog.info(self?.statusMessage ?? "")
                await self?.refreshFromHelper()
            }
        }
    }

    func setApplyAtLogin(_ enabled: Bool) {
        AgentLog.event("setApplyAtLogin \(enabled)")
        client.setApplyAtLogin(enabled) { [weak self] ok, err in
            Task { @MainActor in
                self?.statusMessage = ok ? "Apply at login updated" : (err ?? "Failed")
                await self?.refreshFromHelper()
            }
        }
    }

    func applyTorrentsPreset() {
        triggerBundleIDs = TriggerCatalog.defaultTriggerBundleIDs
        persistAndSyncTriggers(message: "Torrents Apps preset applied")
        AgentLog.event("applyTorrentsPreset count=\(triggerBundleIDs.count)")
    }

    func toggleTrigger(_ bundleID: String) {
        if let idx = triggerBundleIDs.firstIndex(of: bundleID) {
            triggerBundleIDs.remove(at: idx)
        } else {
            triggerBundleIDs.append(bundleID)
        }
        persistAndSyncTriggers()
        AgentLog.event("toggleTrigger \(bundleID) selected=\(triggerBundleIDs.contains(bundleID))")
    }

    func isTriggerSelected(_ bundleID: String) -> Bool {
        triggerBundleIDs.contains(bundleID)
    }

    func removeTrigger(_ bundleID: String) {
        triggerBundleIDs.removeAll { $0 == bundleID }
        persistAndSyncTriggers()
        AgentLog.event("removeTrigger \(bundleID)")
    }

    func addAppViaPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an app to watch for Auto AWDL"
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let bid = Bundle(url: url)?.bundleIdentifier else {
            statusMessage = "Could not read bundle ID"
            AgentLog.error(statusMessage)
            return
        }
        if !triggerBundleIDs.contains(bid) {
            triggerBundleIDs.append(bid)
            persistAndSyncTriggers(message: "Added \(url.deletingPathExtension().lastPathComponent)")
            AgentLog.event("addApp \(bid)")
        } else {
            statusMessage = "Already in list"
        }
    }

    private func persistAndSyncTriggers(message: String? = nil) {
        UserDefaults.standard.set(triggerBundleIDs, forKey: triggersDefaultsKey)
        if let message { statusMessage = message }
        if autoMode {
            client.setAutoMode(true, triggers: triggerBundleIDs) { [weak self] ok, err in
                Task { @MainActor in
                    if !ok { self?.statusMessage = err ?? "Failed to update triggers" }
                    await self?.refreshFromHelper()
                }
            }
        } else {
            publishSnapshot()
        }
    }

    func refreshFromHelper() async {
        refreshHelperStatus()
        guard helperStatus == .enabled else {
            connected = false
            smartAWDLActive = false
            publishSnapshot()
            return
        }
        let ping = await client.pingAsync()
        connected = ping
        guard ping else {
            smartAWDLActive = false
            publishSnapshot()
            return
        }
        if let dict = await client.getStatusAsync() {
            applyStatus(dict)
        }
        publishSnapshot()
    }

    private func applyStatus(_ dict: [String: Any]) {
        let prevSmart = smartAWDLActive
        awdlDisabled = !(dict["awdlUp"] as? Bool ?? true)
        tcpOptimized = dict["tcpFullyOptimized"] as? Bool ?? false
        tcpOptimizedCount = dict["tcpOptimizedCount"] as? Int ?? 0
        tcpTotal = dict["tcpTotal"] as? Int ?? FixValues.tcpSettings.count
        autoMode = dict["autoMode"] as? Bool ?? false
        applyAtLogin = dict["applyTCPAtLogin"] as? Bool ?? true
        smartAWDLActive = dict["smartAWDLActive"] as? Bool ?? false
        archLabel = dict["arch"] as? String ?? "—"
        if let tcp = dict["tcp"] as? [String: String] {
            tcpValues = tcp
        }
        if let ids = dict["triggerBundleIDs"] as? [String], !ids.isEmpty {
            triggerBundleIDs = ids
            UserDefaults.standard.set(ids, forKey: triggersDefaultsKey)
        }
        if prevSmart != smartAWDLActive {
            AgentLog.event("smartAWDLActive → \(smartAWDLActive)")
        }
    }

    private func publishSnapshot() {
        let snap = agentSnapshot()
        snapshotLock.lock()
        cachedSnapshot = snap
        snapshotLock.unlock()
        AgentLog.writeStatusJSON(snap)
    }

    func agentSnapshot() -> [String: Any] {
        [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "helperStatus": helperStatusText,
            "connected": connected,
            "busy": busy,
            "awdlDisabled": awdlDisabled,
            "awdlStatus": awdlStatusText,
            "tcpOptimized": tcpOptimized,
            "tcpOptimizedCount": tcpOptimizedCount,
            "tcpTotal": tcpTotal,
            "autoMode": autoMode,
            "smartAWDLActive": smartAWDLActive,
            "applyAtLogin": applyAtLogin,
            "triggerBundleIDs": triggerBundleIDs,
            "triggerCount": triggerBundleIDs.count,
            "arch": archLabel,
            "statusMessage": statusMessage,
            "trayIcon": trayImageName,
            "tcp": tcpValues,
            "api": [
                "base": "http://127.0.0.1:\(AgentLog.port)",
                "statusFile": AgentLog.statusURL.path,
                "logFile": AgentLog.logURL.path,
            ],
        ]
    }
}
