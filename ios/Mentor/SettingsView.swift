import SwiftUI

struct SettingsView: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        if let user = auth.currentUser {
                            Text(user.email)
                                .font(.system(size: 15))
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
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Settings")
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
