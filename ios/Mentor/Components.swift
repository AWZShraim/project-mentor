import SwiftUI

// MARK: - Card surface

struct CardBackground: ViewModifier {
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension View {
    func cardStyle(padding: CGFloat = 14) -> some View {
        modifier(CardBackground(padding: padding))
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
                .font(.stat(30))
                .foregroundStyle(Theme.purple)
                .neonGlow(Theme.purple)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .cardStyle()
    }
}

struct MacroChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.stat(13))
                .foregroundStyle(Theme.blue)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.blueBg)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.blue.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Screen title (replaces the native nav bar title - we hide the
// system navigation bar on the main tabs entirely so the app doesn't
// read as a stock iOS list-of-screens app)

struct ScreenTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.display(26))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

extension View {
    /// Hides the native nav bar and themes anything that still needs one
    /// (sheets keep their Cancel/Done bar, but dark instead of the
    /// default light material).
    func hiddenNavBar() -> some View {
        self.toolbar(.hidden, for: .navigationBar)
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
