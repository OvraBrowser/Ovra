import Foundation
import SwiftUI

struct WhatsNewEntry: Identifiable {
    var id: String { title }
    let title: String
    let icon: String
    let description: String
    /// Badge colour in the What's New window.
    var colorHex: String = "#5E5CE6"
}

struct WhatsNewVersion: Identifiable {
    var id: String { version }
    let version: String
    let title: String
    let items: [WhatsNewEntry]
}

struct WhatsNewStore {
    static let allVersions: [WhatsNewVersion] = [
        // Add the next release at the top. Notes before 1.0 are from AeroBrowser.
        WhatsNewVersion(
            version: "1.0.0",
            title: "Ovra 1.0",
            items: [
                WhatsNewEntry(title: "A whole new look", icon: "sparkles", description: "Tabs live in a glass sidebar, the toolbar floats over your theme, and pages sit on a clean card.", colorHex: "#5E5CE6"),
                WhatsNewEntry(title: "Privacy at a glance", icon: "shield.lefthalf.filled", description: "Click the shield in the address bar to see cookies, storage and connection, and switch blocking on or off.", colorHex: "#0A84FF"),
                WhatsNewEntry(title: "Themes, your way", icon: "paintpalette.fill", description: "New built-in themes, plus custom themes with up to four colors, any direction, glass and grain.", colorHex: "#BF5AF2"),
                WhatsNewEntry(title: "Share themes", icon: "square.and.arrow.up", description: "Export a theme as an .ovratheme file. Anyone with Ovra can double-click it to add it.", colorHex: "#FF9F0A"),
                WhatsNewEntry(title: "Backups", icon: "arrow.up.arrow.down", description: "Save settings, themes, favorites and bookmarks to an .ovrabackup file and restore them on any Mac.", colorHex: "#30D158"),
                WhatsNewEntry(title: "Downloads that work", icon: "arrow.down.circle.fill", description: "Live progress and sizes, downloads keep going when you switch tabs, and cancel cleans up.", colorHex: "#64D2FF"),
                WhatsNewEntry(title: "Redesigned Settings", icon: "gearshape.fill", description: "Searchable settings with grouped sections, your profile name, and a full reset.", colorHex: "#8E8E93")
            ]
        ),
        WhatsNewVersion(
            version: "0.0.2-alpha",
            title: "v0.0.2 Alpha",
            items: [
                WhatsNewEntry(title: "Settings Page", icon: "gear", description: "Added settings view to configure your browser."),
                WhatsNewEntry(title: "OvraAI View", icon: "sparkles", description: "Placeholder for future AI features."),
                WhatsNewEntry(title: "Theme Settings", icon: "paintpalette", description: "Change and preview your Ovra theme."),
                WhatsNewEntry(title: "Advanced Settings", icon: "gearshape.2.fill", description: "Stub for upcoming advanced tweaks."),
                WhatsNewEntry(title: "Design Changes", icon: "rectangle.3.offgrid.bubble.left", description: "Blurred UI, removed stroke/shadows, improved visuals.")
            ]
        ),
        WhatsNewVersion(
            version: "0.0.1-alpha",
            title: "v0.0.1 Alpha",
            items: [
                WhatsNewEntry(title: "Early Access", icon: "flame", description: "Initial release of Ovra (Alpha stage).")
            ]
        )
    ]
}
