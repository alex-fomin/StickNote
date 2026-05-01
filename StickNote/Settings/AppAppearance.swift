import AppKit
import Defaults
import SwiftUI

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

    /// For ``SwiftUI.View/preferredColorScheme(_:)``. `nil` means follow the system appearance.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
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
