import SwiftUI

struct CoachView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenTitle(title: "Coach")

                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.purple)
                        .shadow(color: Theme.purple.opacity(0.5), radius: 12)
                    Text("AI Coach")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Coming soon")
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .hiddenNavBar()
        }
    }
}

#Preview {
    CoachView()
}
