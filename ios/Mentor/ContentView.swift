import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()

    var body: some View {
        Group {
            if auth.isSignedIn {
                signedInView
            } else {
                AuthView(auth: auth)
            }
        }
        .task {
            if auth.isSignedIn {
                await auth.loadCurrentUser()
            }
        }
    }

    private var signedInView: some View {
        VStack(spacing: 16) {
            Text("Mentor").font(.largeTitle.bold())
            if let user = auth.currentUser {
                Text("Signed in as \(user.email)")
            } else {
                ProgressView()
            }
            Button("Sign Out") { auth.signOut() }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
