import Foundation

enum CognitoError: Error, LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .invalidResponse: return "Unexpected response from Cognito"
        }
    }
}

struct CognitoTokens {
    let accessToken: String
    let idToken: String
    let refreshToken: String
    let expiresIn: Int
}

// Raw calls to Cognito's JSON API instead of the Amplify SDK - our app
// client has no secret, so these are unsigned, plain HTTPS+JSON requests.
final class CognitoAuthService {
    private let region = "ca-central-1"
    private let clientId = "l1s3vvoleb4goagluak1atg8o"

    private var endpoint: URL {
        URL(string: "https://cognito-idp.\(region).amazonaws.com/")!
    }

    private func request(target: String, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        req.setValue("AWSCognitoIdentityProviderService.\(target)", forHTTPHeaderField: "X-Amz-Target")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (json?["message"] as? String) ?? (json?["__type"] as? String) ?? "Cognito request failed"
            throw CognitoError.server(message)
        }
        return json ?? [:]
    }

    func signUp(email: String, password: String) async throws {
        _ = try await request(target: "SignUp", body: [
            "ClientId": clientId,
            "Username": email,
            "Password": password,
            "UserAttributes": [["Name": "email", "Value": email]],
        ])
    }

    func confirmSignUp(email: String, code: String) async throws {
        _ = try await request(target: "ConfirmSignUp", body: [
            "ClientId": clientId,
            "Username": email,
            "ConfirmationCode": code,
        ])
    }

    func signIn(email: String, password: String) async throws -> CognitoTokens {
        let json = try await request(target: "InitiateAuth", body: [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": clientId,
            "AuthParameters": ["USERNAME": email, "PASSWORD": password],
        ])

        guard let result = json["AuthenticationResult"] as? [String: Any],
              let accessToken = result["AccessToken"] as? String,
              let idToken = result["IdToken"] as? String,
              let refreshToken = result["RefreshToken"] as? String,
              let expiresIn = result["ExpiresIn"] as? Int
        else {
            throw CognitoError.invalidResponse
        }

        return CognitoTokens(accessToken: accessToken, idToken: idToken, refreshToken: refreshToken, expiresIn: expiresIn)
    }

    /// Cognito doesn't return a new refresh token on this flow (no
    /// rotation configured on our app client) - the caller keeps using
    /// the same one it already had.
    func refreshAccessToken(refreshToken: String) async throws -> CognitoTokens {
        let json = try await request(target: "InitiateAuth", body: [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": clientId,
            "AuthParameters": ["REFRESH_TOKEN": refreshToken],
        ])

        guard let result = json["AuthenticationResult"] as? [String: Any],
              let accessToken = result["AccessToken"] as? String,
              let idToken = result["IdToken"] as? String,
              let expiresIn = result["ExpiresIn"] as? Int
        else {
            throw CognitoError.invalidResponse
        }

        return CognitoTokens(
            accessToken: accessToken, idToken: idToken, refreshToken: refreshToken, expiresIn: expiresIn
        )
    }
}
