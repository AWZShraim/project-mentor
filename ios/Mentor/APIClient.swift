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
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// Retries once with a refreshed access token on a 401 - access
    /// tokens expire after 60 minutes and this is the only place that
    /// needs to know that.
    private func request(
        _ path: String,
        method: String = "GET",
        query: [String: String] = [:],
        body: Data? = nil,
        accessToken: String
    ) async throws -> Data {
        do {
            return try await performRequest(
                path, method: method, query: query, body: body, accessToken: accessToken
            )
        } catch APIError.server(401) {
            guard let newToken = await AuthTokenStore.refreshAccessToken() else {
                throw APIError.server(401)
            }
            return try await performRequest(
                path, method: method, query: query, body: body, accessToken: newToken
            )
        }
    }

    private func performRequest(
        _ path: String,
        method: String,
        query: [String: String],
        body: Data?,
        accessToken: String
    ) async throws -> Data {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    func me(accessToken: String) async throws -> MentorUser {
        let data = try await request("me", accessToken: accessToken)
        return try decoder.decode(MentorUser.self, from: data)
    }

    func listExercises(accessToken: String) async throws -> [Exercise] {
        let data = try await request("exercises", accessToken: accessToken)
        return try decoder.decode([Exercise].self, from: data)
    }

    func listTemplates(accessToken: String) async throws -> [WorkoutTemplate] {
        let data = try await request("workout-templates", accessToken: accessToken)
        return try decoder.decode([WorkoutTemplate].self, from: data)
    }

    func createTemplate(
        name: String,
        exerciseIds: [String],
        accessToken: String
    ) async throws -> WorkoutTemplate {
        let payload: [String: Any] = ["name": name, "exercise_ids": exerciseIds]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await request(
            "workout-templates", method: "POST", body: body, accessToken: accessToken
        )
        return try decoder.decode(WorkoutTemplate.self, from: data)
    }

    func updateTemplate(
        id: String,
        name: String,
        exerciseIds: [String],
        accessToken: String
    ) async throws -> WorkoutTemplate {
        let payload: [String: Any] = ["name": name, "exercise_ids": exerciseIds]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await request(
            "workout-templates/\(id)", method: "PATCH", body: body, accessToken: accessToken
        )
        return try decoder.decode(WorkoutTemplate.self, from: data)
    }

    func deleteTemplate(id: String, accessToken: String) async throws {
        _ = try await request(
            "workout-templates/\(id)", method: "DELETE", accessToken: accessToken
        )
    }

    func listWorkoutLogs(date: String, accessToken: String) async throws -> [WorkoutLogEntryRecord] {
        let data = try await request(
            "workout-logs", query: ["date": date], accessToken: accessToken
        )
        return try decoder.decode([WorkoutLogEntryRecord].self, from: data)
    }

    func createWorkoutLog(
        _ payload: WorkoutLogCreatePayload,
        accessToken: String
    ) async throws -> WorkoutLogEntryRecord {
        let body = try encoder.encode(payload)
        let data = try await request(
            "workout-logs", method: "POST", body: body, accessToken: accessToken
        )
        return try decoder.decode(WorkoutLogEntryRecord.self, from: data)
    }

    func updateWorkoutLog(
        id: String,
        sets: [WorkoutSetPayload],
        accessToken: String
    ) async throws -> WorkoutLogEntryRecord {
        let body = try encoder.encode(WorkoutLogUpdatePayload(sets: sets))
        let data = try await request(
            "workout-logs/\(id)", method: "PATCH", body: body, accessToken: accessToken
        )
        return try decoder.decode(WorkoutLogEntryRecord.self, from: data)
    }

    func deleteWorkoutLog(id: String, accessToken: String) async throws {
        _ = try await request(
            "workout-logs/\(id)", method: "DELETE", accessToken: accessToken
        )
    }
}
