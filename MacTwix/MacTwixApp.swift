import SwiftUI

@main
struct MacTwixApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(appModel)
        } label: {
            Image(nsImage: appModel.autoMode
                  ? TrayIconRenderer.makeIcon(withBolt: true)
                  : TrayIconRenderer.makeIcon(withBolt: false))
                .help(appModel.trayAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Window("Watched Apps", id: "watched-apps") {
            WatchedAppsView()
                .environmentObject(appModel)
        }
        .windowResizability(.contentSize)

        Window("TCP Details", id: "tcp-details") {
            TCPDetailsView()
                .environmentObject(appModel)
        }
        .windowResizability(.contentSize)

        Window("Preferences", id: "preferences") {
            PreferencesView()
                .environmentObject(appModel)
        }
        .windowResizability(.contentSize)

        Window("Developer", id: "developer") {
            DeveloperView()
                .environmentObject(appModel)
        }
        .windowResizability(.contentSize)
    }
}
