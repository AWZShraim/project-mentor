import SwiftUI

struct CoachView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenTitle(title: "Coach")

                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.purple)
                        .neonGlow(Theme.purple, radius: 24)
                    Text("AI Coach")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Coming soon")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AmbientBackground())
            .hiddenNavBar()
        }
    }
}

#Preview {
    CoachView()
}
