import SwiftUI

enum WWColor {
    static let white = Color(hex: "#FFFFFF")
    static let growGreen = Color(hex: "#4CAF7D")
    static let morningGold = Color(hex: "#F0C060")
    static let surface = Color(hex: "#F5F5F3")
    static let nearBlack = Color(hex: "#1A1A1A")
    static let darkBackground = Color(hex: "#0F0F0F")
    static let muted = Color(hex: "#888884")

    static let cardBackground = surface

    // Backward-compatible aliases while migrating older screens.
    static let alabaster = white
    static let sage = growGreen
    static let sapphire = growGreen
    static let charcoal = nearBlack
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)

        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
