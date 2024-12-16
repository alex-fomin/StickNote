import SwiftUI

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
}
