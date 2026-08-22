import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: MentorUser?
    @Published var errorMessage: String?
    @Published var pendingConfirmation = false

    private let auth = CognitoAuthService()
    private let api = APIClient()

    init() {
        if AuthTokenStore.current != nil {
            isSignedIn = true
        }
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            try await auth.signUp(email: email, password: password)
            pendingConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmSignUp(email: String, code: String) async {
        errorMessage = nil
        do {
            try await auth.confirmSignUp(email: email, code: code)
            pendingConfirmation = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let tokens = try await auth.signIn(email: email, password: password)
            KeychainHelper.save(tokens.accessToken, forKey: AuthTokenStore.key)
            isSignedIn = true
            await loadCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        KeychainHelper.delete(forKey: AuthTokenStore.key)
        isSignedIn = false
        currentUser = nil
    }

    func loadCurrentUser() async {
        guard let token = AuthTokenStore.current else { return }
        do {
            currentUser = try await api.me(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
