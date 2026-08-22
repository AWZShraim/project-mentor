import SwiftUI

struct SettingsView: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = auth.currentUser {
                        LabeledContent("Email", value: user.email)
                    } else {
                        ProgressView()
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        auth.signOut()
                    }
                }
            }
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
