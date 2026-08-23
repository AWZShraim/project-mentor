import SwiftUI

struct SettingsView: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenTitle(title: "Settings")

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Account")
                                .font(.system(size: 12, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(Theme.textSecondary)
                            if let user = auth.currentUser {
                                Text(user.email)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                            } else {
                                ProgressView().tint(Theme.purple)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()

                        Button("Sign Out") {
                            auth.signOut()
                        }
                        .buttonStyle(.mentorSecondary(tint: Theme.danger))
                    }
                    .padding(18)
                }
                .tabBarSafeArea()
            }
            .background(AmbientBackground())
            .hiddenNavBar()
            .task {
                if auth.currentUser == nil {
                    await auth.loadCurrentUser()
                }
            }
        }
    }
}

#Preview {
    SettingsView(auth: AuthViewModel())
}
