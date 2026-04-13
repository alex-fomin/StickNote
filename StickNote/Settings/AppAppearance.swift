import AppKit
import Defaults

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` means follow the system appearance.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum AppAppearance {
    @MainActor
    static func applyFromDefaults() {
        let raw = Defaults[.appAppearance]
        let pref = AppAppearancePreference(rawValue: raw) ?? .system
        NSApp.appearance = pref.nsAppearance
    }
}
