import SwiftUI
import AppKit

extension Color {
    static func fromString(_ hex: String) -> Color {
        if !hex.hasPrefix("#") {
            return Color(hex)
        }
        // Remove the hash if it exists
        let hexString = String(hex.dropFirst())

        // Convert hex string to integer
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)

        // Extract RGB components
        let red = Double((hexNumber & 0xFF0000) >> 16) / 255.0
        let green = Double((hexNumber & 0x00FF00) >> 8) / 255.0
        let blue = Double(hexNumber & 0x0000FF) / 255.0

        // Initialize the Color
        return Color(red: red, green: green, blue: blue)
    }
    
    func toHex() -> String {
            // Convert SwiftUI Color to NSColor
            let nsColor = NSColor(self)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0

            // Extract RGBA components
            nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            // Convert to 0–255 integer values
            let r = Int(red * 255)
            let g = Int(green * 255)
            let b = Int(blue * 255)

            // Format as hex string
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    
    func isLight() -> Bool {
        // Convert Color to RGB components
        let uiColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Convert to 0-255 range
        let r = red * 255
        let g = green * 255
        let b = blue * 255
        
        // Calculate luminance
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        
        return luminance > 128 // Returns true if light, false if dark
    }
}

extension NSColor {
    static func fromString(_ hex: String) -> NSColor {
        // Remove the hash if it exists
        let hexString = String(hex.dropFirst())
        
        // Convert hex string to integer
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        
        // Extract RGB components
        let red = Double((hexNumber & 0xFF0000) >> 16) / 255.0
        let green = Double((hexNumber & 0x00FF00) >> 8) / 255.0
        let blue = Double(hexNumber & 0x0000FF) / 255.0
        
        // Initialize the Color
        return NSColor(red: red, green: green, blue: blue, alpha: 0.0)
    }
}
