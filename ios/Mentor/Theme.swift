import SwiftUI

extension Color {
    init(hex: String) {
        var scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Purple-primary, blue-for-structure-only. Dark mode only, by design -
/// no light variant.
enum Theme {
    static let background = Color(hex: "0A0810")
    static let surface = Color(hex: "16111F")
    static let surfaceElevated = Color(hex: "1F1830")
    static let border = Color(hex: "332A47")

    static let textPrimary = Color(hex: "F3EFFA")
    static let textSecondary = Color(hex: "9691AC")

    /// Primary accent - active states, headline numbers, primary actions.
    static let purple = Color(hex: "A855F7")
    static let purpleSoft = Color(hex: "C77DFF")

    /// Structural accent only - breakdown/supporting data (macro chips,
    /// badges, secondary metrics). Never used for navigation or primary
    /// actions, so its appearance stays meaningful rather than decorative.
    static let blue = Color(hex: "38BDF8")
    static let blueBg = Color(hex: "142433")

    static let danger = Color(hex: "F87171")
}

extension Font {
    /// For stat/data readouts - calories, weights, reps, macros. Monospaced
    /// SF gives the "data terminal" feel without bundling a custom font.
    static func stat(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
