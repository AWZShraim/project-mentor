import Foundation

struct MentorUser: Decodable, Identifiable {
    let id: String
    let email: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }
}

enum APIError: Error, LocalizedError {
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let code): return "API request failed (HTTP \(code))"
        case .invalidResponse: return "Unexpected API response"
        }
    }
}

final class APIClient {
    // No TLS yet (tracked in infra/README.md known gaps) - matches the
    // ATS exception added for this IP in Info.plist.
    private let baseURL = URL(string: "http://3.97.53.211:8000")!

    func me(accessToken: String) async throws -> MentorUser {
        var req = URLRequest(url: baseURL.appendingPathComponent("me"))
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(MentorUser.self, from: data)
    }
}
