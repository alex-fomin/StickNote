import AppKit
import SwiftUI

/// On-screen sticky colors: in dark mode, derives darker tinted surfaces and contrasting text from stored hex.
/// Persistence and export continue to use model hex strings unchanged.
enum NoteDisplayColors {

    /// Matches SwiftUI dark mode for the app (`NSApp` + `colorScheme`).
    static var isEffectiveDarkInterface: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func displayColors(
        storedBgHex: String,
        storedFgHex: String,
        colorScheme: ColorScheme
    ) -> (background: Color, foreground: Color) {
        displayColors(storedBgHex: storedBgHex, storedFgHex: storedFgHex, isDark: colorScheme == .dark)
    }

    static func displayColors(
        storedBgHex: String,
        storedFgHex: String,
        isDark: Bool
    ) -> (background: Color, foreground: Color) {
        if !isDark {
            return (Color.fromString(storedBgHex), Color.fromString(storedFgHex))
        }
        let bgNS = opaqueNSColor(fromHex: storedBgHex)
        let darkBg = darkenedStickyBackground(bgNS)
        let fgNS = foregroundForDarkStickyBackground(background: darkBg)
        return (Color(nsColor: darkBg), Color(nsColor: fgNS))
    }

    static func displayBackgroundNSColor(storedBgHex: String, isDark: Bool) -> NSColor {
        let base = opaqueNSColor(fromHex: storedBgHex)
        if !isDark { return base }
        return darkenedStickyBackground(base)
    }

    // MARK: - Private

    private static func opaqueNSColor(fromHex hex: String) -> NSColor {
        NSColor.fromString(hex).withAlphaComponent(1.0)
    }

    private static func darkenedStickyBackground(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return color.withAlphaComponent(1.0)
        }
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let newS = min(0.55, max(0.1, s * 0.52 + 0.06))
        let newB = max(0.12, min(0.4, b * 0.26 + 0.09))
        return NSColor(calibratedHue: h, saturation: newS, brightness: newB, alpha: 1.0)
    }

    private static func foregroundForDarkStickyBackground(background: NSColor) -> NSColor {
        let l = relativeLuminance(background)
        if l > 0.45 {
            return NSColor(calibratedWhite: 0.09, alpha: 1.0)
        }
        return NSColor(calibratedWhite: 0.93, alpha: 1.0)
    }

    private static func relativeLuminance(_ color: NSColor) -> CGFloat {
        guard let c = color.usingColorSpace(.sRGB) else { return 0.5 }
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linearize(_ u: CGFloat) -> CGFloat {
            u <= 0.03928 ? (u / 12.92) : pow((u + 0.055) / 1.055, 2.4)
        }
        let R = linearize(r)
        let G = linearize(g)
        let B = linearize(b)
        return 0.2126 * R + 0.7152 * G + 0.0722 * B
    }
}
