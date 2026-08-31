import SwiftUI
import UIKit

// MARK: - Keyboard dismissal

extension View {
    /// Tapping anywhere outside a focused field dismisses the keyboard.
    /// SwiftUI has no built-in affordance for this - without it the only
    /// way off the keyboard is submitting the field, which is why this
    /// is applied broadly rather than per-screen.
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
        }
    }
}

// MARK: - Card surface

struct CardBackground: ViewModifier {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = Theme.cardRadius
    /// Hero cards (e.g. the daily totals readout) get an ambient purple
    /// bloom instead of a plain drop shadow, so they read as "lit up"
    /// rather than just elevated.
    var glow: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.cardFill)
            .overlay(
                // Base identity border.
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(glow ? Theme.purple.opacity(0.55) : Theme.border, lineWidth: 1)
            )
            .overlay(
                // Top glass sheen - a hairline that fades from bright to
                // nothing, so the card reads as lit from above rather
                // than a uniformly flat panel.
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.45), radius: 16, y: 10)
            .shadow(color: glow ? Theme.purple.opacity(0.45) : .clear, radius: 34)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 18, cornerRadius: CGFloat = Theme.cardRadius, glow: Bool = false) -> some View {
        modifier(CardBackground(padding: padding, cornerRadius: cornerRadius, glow: glow))
    }
}

// MARK: - Text field

struct ThemedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

extension TextFieldStyle where Self == ThemedTextFieldStyle {
    static var themed: ThemedTextFieldStyle { ThemedTextFieldStyle() }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.background)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(Theme.purple)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Theme.purple.opacity(configuration.isPressed ? 0.2 : 0.45), radius: 10)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.purple

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(tint)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var mentorPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var mentorSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func mentorSecondary(tint: Color) -> SecondaryButtonStyle { SecondaryButtonStyle(tint: tint) }
}

// MARK: - Stat / macro readouts

struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.stat(38, weight: .heavy))
                .foregroundStyle(Theme.purple)
                .neonGlow(Theme.purple, radius: 22)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .cardStyle(glow: true)
    }
}

struct MacroChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.stat(18, weight: .heavy))
                .foregroundStyle(Theme.blue)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Theme.blueBg, Theme.blueBg.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.blue.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Theme.blue.opacity(0.18), radius: 12)
    }
}

// MARK: - Screen title (replaces the native nav bar title - we hide the
// system navigation bar on the main tabs entirely so the app doesn't
// read as a stock iOS list-of-screens app)

struct ScreenTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.display(28))
            // Belt-and-suspenders: if ChakraPetch isn't registered, the
            // custom font silently falls back to system-regular. Chaining
            // fontWeight keeps titles bold either way instead of looking
            // thin when the font resource is missing.
            .fontWeight(.bold)
            .tracking(0.3)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }
}

extension View {
    /// Hides the native nav bar and themes anything that still needs one
    /// (sheets keep their Cancel/Done bar, but dark instead of the
    /// default light material).
    func hiddenNavBar() -> some View {
        self
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    func darkNavBar() -> some View {
        self
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Section header (bypasses the default all-caps system style)

struct SectionHeader: View {
    let title: String
    var trailing: AnyView?

    init(_ title: String, trailing: AnyView? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            trailing
        }
    }
}

// MARK: - Empty state

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Theme.textSecondary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .cardStyle()
    }
}
