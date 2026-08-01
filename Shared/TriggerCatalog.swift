import Foundation

/// Known apps that can trigger Auto AWDL, plus named presets.
enum TriggerCatalog {
    struct App: Identifiable, Hashable, Sendable {
        let id: String // bundle ID
        let name: String
        let bundleID: String
    }

    struct Preset: Identifiable, Sendable {
        let id: String
        let name: String
        let bundleIDs: [String]
    }

    /// Popular torrent / multi-connection clients.
    static let torrentApps: [App] = [
        .init(id: "org.qbittorrent.qBittorrent", name: "qBittorrent", bundleID: "org.qbittorrent.qBittorrent"),
        .init(id: "org.deluge", name: "Deluge", bundleID: "org.deluge"),
        .init(id: "org.m0k.transmission", name: "Transmission", bundleID: "org.m0k.transmission"),
        .init(id: "org.transmission-qt", name: "Transmission (Qt)", bundleID: "org.transmission-qt"),
        .init(id: "com.bittorrent.BitTorrent", name: "BitTorrent", bundleID: "com.bittorrent.BitTorrent"),
        .init(id: "com.bittorrent.uTorrent", name: "µTorrent", bundleID: "com.bittorrent.uTorrent"),
        .init(id: "com.flood-ui.flood", name: "Flood", bundleID: "com.flood-ui.flood"),
        .init(id: "io.github.tixati", name: "Tixati", bundleID: "io.github.tixati"),
        .init(id: "net.sourceforge.Vuze", name: "Vuze / Azureus", bundleID: "net.sourceforge.Vuze"),
        .init(id: "org.frostwire.FrostWire", name: "FrostWire", bundleID: "org.frostwire.FrostWire"),
        .init(id: "com.aria2.aria2c", name: "aria2", bundleID: "com.aria2.aria2c"),
        .init(id: "org.freedownloadmanager.fdm6", name: "Free Download Manager", bundleID: "org.freedownloadmanager.fdm6"),
    ]

    static let presets: [Preset] = [
        .init(
            id: "torrents",
            name: "Torrents Apps",
            bundleIDs: torrentApps.map(\.bundleID)
        ),
    ]

    static var defaultTriggerBundleIDs: [String] {
        presets.first(where: { $0.id == "torrents" })?.bundleIDs
            ?? torrentApps.map(\.bundleID)
    }

    static func displayName(for bundleID: String) -> String {
        if let known = torrentApps.first(where: { $0.bundleID == bundleID }) {
            return known.name
        }
        if let last = bundleID.split(separator: ".").last {
            return String(last)
        }
        return bundleID
    }
}
