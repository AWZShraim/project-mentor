import Foundation

/// v1 goals only ever come back as a nutrition target - this mirrors the
/// exact shape the backend's guardrails clamp `Goal.value` to for
/// `goal_type == "calorie_target"`.
struct NutritionTargetValue: Codable, Hashable {
    let dailyCalories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    enum CodingKeys: String, CodingKey {
        case dailyCalories = "daily_calories"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
}

struct GoalRecord: Codable, Identifiable {
    let id: String
    let goalType: String
    let value: NutritionTargetValue
    let status: String
    let reasoning: String?
    let createdBy: String
    let effectiveAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status, reasoning, value
        case goalType = "goal_type"
        case createdBy = "created_by"
        case effectiveAt = "effective_at"
        case createdAt = "created_at"
    }
}

struct CoachCheckInResult: Codable {
    let proposal: GoalRecord?
    let message: String
}

struct HealthMetricRecord: Codable, Identifiable {
    let id: String
    let metricType: String
    let value: Double
    let unit: String
    let recordedAt: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case id, value, unit, source
        case metricType = "metric_type"
        case recordedAt = "recorded_at"
    }
}

struct HealthMetricCreatePayload: Codable {
    let metricType: String
    let value: Double
    let unit: String
    let recordedAt: String

    enum CodingKeys: String, CodingKey {
        case value, unit
        case metricType = "metric_type"
        case recordedAt = "recorded_at"
    }
}

/// A turn in the Mentor chat. `id` is server-assigned for persisted
/// messages, or a freshly generated UUID string for an optimistic local
/// entry shown before the server responds.
struct ChatMessageRecord: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case createdAt = "created_at"
    }
}

/// A one-off action (e.g. logging a food entry) the Mentor chat proposed.
/// `payload` (the concrete params it'll execute with) is intentionally not
/// decoded here - the UI only needs `summary`/`reasoning` to show the
/// approval card.
struct AgentActionRecord: Codable, Identifiable {
    let id: String
    let actionType: String
    let summary: String
    let reasoning: String?
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, summary, reasoning, status
        case actionType = "action_type"
        case createdAt = "created_at"
    }
}

struct ChatResponsePayload: Codable {
    let reply: String
    let proposedGoal: GoalRecord?
    let proposedAction: AgentActionRecord?

    enum CodingKeys: String, CodingKey {
        case reply
        case proposedGoal = "proposed_goal"
        case proposedAction = "proposed_action"
    }
}

struct DashboardRecord: Codable {
    let todayCalories: Double
    let todayProteinG: Double
    let todayCarbsG: Double
    let todayFatG: Double
    let activeGoal: GoalRecord?
    let latestWeight: HealthMetricRecord?
    let weightChange7d: Double?
    let sleepHoursLastNight: Double?
    let insightText: String?
    let insightGeneratedAt: String?

    enum CodingKeys: String, CodingKey {
        case todayCalories = "today_calories"
        case todayProteinG = "today_protein_g"
        case todayCarbsG = "today_carbs_g"
        case todayFatG = "today_fat_g"
        case activeGoal = "active_goal"
        case latestWeight = "latest_weight"
        case weightChange7d = "weight_change_7d"
        case sleepHoursLastNight = "sleep_hours_last_night"
        case insightText = "insight_text"
        case insightGeneratedAt = "insight_generated_at"
    }
}
