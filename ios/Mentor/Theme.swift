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
/// no light variant. Surfaces lean visibly purple rather than neutral
/// gray - a desaturated near-black reads as "just dark mode," not
/// cyberpunk.
enum Theme {
    static let background = Color(hex: "0A0810")
    static let surface = Color(hex: "1C1130")
    static let surfaceElevated = Color(hex: "271A47")
    static let border = Color(hex: "4C3670")

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

    /// Cards read as flat paint chips without this - a faint top-to-bottom
    /// lightening is what separates "elevated glass panel" from "colored
    /// rectangle." Used as the fill for every card via cardStyle().
    static let cardFill = LinearGradient(
        colors: [surfaceElevated.opacity(0.85), surface],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardRadius: CGFloat = 22
}

extension Font {
    /// For stat/data readouts - calories, weights, reps, macros. Monospaced
    /// SF gives the "data terminal" feel without bundling a custom font.
    static func stat(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Screen titles and other brand-carrying headers. Chakra Petch is
    /// bundled as a font resource (see Info.plist UIAppFonts); falls back
    /// to the system font automatically if the exact PostScript name
    /// doesn't match what's registered - never crashes.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name = weight == .bold ? "ChakraPetch-Bold" : "ChakraPetch-SemiBold"
        return .custom(name, size: size)
    }
}

extension View {
    /// Stronger, more deliberate glow than a default shadow - for the
    /// handful of elements that should actually read as "lit up"
    /// (headline stat numbers, the brand wordmark).
    func neonGlow(_ color: Color, radius: CGFloat = 16) -> some View {
        self
            .shadow(color: color.opacity(0.8), radius: radius / 2)
            .shadow(color: color.opacity(0.5), radius: radius)
    }
}

/// Every screen background: flat near-black plus a soft purple bloom
/// bleeding down from the top. Flat black alone reads as generic "dark
/// mode"; a lit environment behind the content is what makes the accent
/// colors feel like they're actually glowing against something, not just
/// drawn on a black rectangle.
struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.purple.opacity(0.20), Theme.purple.opacity(0.0)],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .frame(height: 460)
            .frame(maxWidth: .infinity)
            .offset(y: -180)

            RadialGradient(
                colors: [Theme.blue.opacity(0.10), Theme.blue.opacity(0.0)],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 340
            )
            .frame(height: 420)
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea()
    }
}
