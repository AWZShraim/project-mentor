import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()

    var body: some View {
        Group {
            if auth.isSignedIn {
                MainTabView(auth: auth)
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
}

#Preview {
    ContentView()
}
