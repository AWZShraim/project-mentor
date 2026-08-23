import SwiftUI

struct MainTabView: View {
    @ObservedObject var auth: AuthViewModel
    @State private var selectedTab: MentorTab = .nutrition

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            // All four tabs stay mounted and are only hidden/shown, so each
            // keeps its own @StateObject alive across switches (matching
            // native TabView persistence) instead of refetching every tap.
            ForEach(MentorTab.allCases, id: \.self) { tab in
                tabContent(tab)
                    .opacity(selectedTab == tab ? 1 : 0)
                    .allowsHitTesting(selectedTab == tab)
                    .accessibilityHidden(selectedTab != tab)
            }

            FloatingTabBar(selectedTab: $selectedTab)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: MentorTab) -> some View {
        switch tab {
        case .coach:
            CoachView()
        case .nutrition:
            NutritionView()
        case .exercises:
            ExercisesView()
        case .settings:
            SettingsView(auth: auth)
        }
    }
}

enum MentorTab: CaseIterable {
    case coach, nutrition, exercises, settings

    var icon: String {
        switch self {
        case .coach: return "sparkles"
        case .nutrition: return "fork.knife"
        case .exercises: return "dumbbell.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var label: String {
        switch self {
        case .coach: return "Coach"
        case .nutrition: return "Nutrition"
        case .exercises: return "Exercises"
        case .settings: return "Settings"
        }
    }
}

/// Custom floating pill nav — replaces the stock TabView chrome (flat,
/// edge-to-edge, system material) which is the single biggest tell that
/// reads as "default iOS app" rather than a designed product.
struct FloatingTabBar: View {
    @Binding var selectedTab: MentorTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MentorTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .background(
            Capsule()
                .fill(Theme.surface.opacity(0.7))
        )
        .overlay(
            Capsule()
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        .shadow(color: Theme.purple.opacity(0.25), radius: 24, y: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }

    private func tabButton(_ tab: MentorTab) -> some View {
        let isSelected = tab == selectedTab

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Theme.purple)
                        .frame(width: 46, height: 46)
                        .shadow(color: Theme.purple.opacity(0.7), radius: 12)
                        .transition(.scale.combined(with: .opacity))
                }
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.background : Theme.textSecondary)
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
    }
}

/// Reserves room at the bottom of scroll content so the last row clears
/// the floating tab bar instead of sitting underneath it.
struct TabBarSafeArea: ViewModifier {
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 78)
        }
    }
}

extension View {
    func tabBarSafeArea() -> some View {
        modifier(TabBarSafeArea())
    }
}

#Preview {
    MainTabView(auth: AuthViewModel())
}
