import Foundation

enum AuthTokenStore {
    static let key = "mentor.accessToken"

    static var current: String? {
        KeychainHelper.read(forKey: key)
    }
}
