import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let userId: String?
    let name: String
    let category: String?
    let muscleGroups: [String]?
    let equipment: String?
    let movementPattern: String?
    let loggingType: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, equipment
        case userId = "user_id"
        case muscleGroups = "muscle_groups"
        case movementPattern = "movement_pattern"
        case loggingType = "logging_type"
    }
}

struct WorkoutTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let exercises: [Exercise]
}

struct WorkoutSetPayload: Codable {
    let setNumber: Int
    let reps: Int?
    let weight: Double?
    let weightUnit: String?
    let durationSeconds: Int?
    let distance: Double?
    let distanceUnit: String?

    enum CodingKeys: String, CodingKey {
        case reps, weight, distance
        case setNumber = "set_number"
        case weightUnit = "weight_unit"
        case durationSeconds = "duration_seconds"
        case distanceUnit = "distance_unit"
    }
}

struct WorkoutSetRecord: Codable, Identifiable {
    let id: String
    let setNumber: Int
    let reps: Int?
    let weight: Double?
    let weightUnit: String?
    let durationSeconds: Int?
    let distance: Double?
    let distanceUnit: String?

    enum CodingKeys: String, CodingKey {
        case id, reps, weight, distance
        case setNumber = "set_number"
        case weightUnit = "weight_unit"
        case durationSeconds = "duration_seconds"
        case distanceUnit = "distance_unit"
    }
}

struct WorkoutLogCreatePayload: Codable {
    let exerciseId: String
    let loggedAt: String
    let notes: String?
    let sets: [WorkoutSetPayload]

    enum CodingKeys: String, CodingKey {
        case notes, sets
        case exerciseId = "exercise_id"
        case loggedAt = "logged_at"
    }
}

struct WorkoutLogEntryRecord: Codable, Identifiable {
    let id: String
    let exercise: Exercise
    let loggedAt: String
    let notes: String?
    let sets: [WorkoutSetRecord]

    enum CodingKeys: String, CodingKey {
        case id, exercise, notes, sets
        case loggedAt = "logged_at"
    }
}

enum DateFormatting {
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone.current
        return f
    }()
}
