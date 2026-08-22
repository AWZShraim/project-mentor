import Foundation

enum AuthTokenStore {
    static let key = "mentor.accessToken"
    static let refreshKey = "mentor.refreshToken"

    static var current: String? {
        KeychainHelper.read(forKey: key)
    }

    static var currentRefreshToken: String? {
        KeychainHelper.read(forKey: refreshKey)
    }

    static func save(accessToken: String, refreshToken: String) {
        KeychainHelper.save(accessToken, forKey: key)
        KeychainHelper.save(refreshToken, forKey: refreshKey)
    }

    static func clear() {
        KeychainHelper.delete(forKey: key)
        KeychainHelper.delete(forKey: refreshKey)
    }

    /// Uses the stored refresh token to get a new access token when a
    /// request comes back 401 (access tokens expire after 60 minutes).
    /// Clears everything on failure, since that means the session is
    /// truly dead - the next screen that checks `current` will see nil.
    static func refreshAccessToken() async -> String? {
        guard let refreshToken = currentRefreshToken else { return nil }
        do {
            let tokens = try await CognitoAuthService().refreshAccessToken(refreshToken: refreshToken)
            save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            return tokens.accessToken
        } catch {
            clear()
            return nil
        }
    }
}
