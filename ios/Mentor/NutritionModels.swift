import Foundation

struct FoodItem: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let brand: String?
    let sourceType: String
    let externalId: String?
    let servingSize: Double
    let servingUnit: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, brand, calories
        case userId = "user_id"
        case sourceType = "source_type"
        case externalId = "external_id"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
    }
}

struct FoodItemCreatePayload: Codable {
    let name: String
    let brand: String?
    let sourceType: String
    let externalId: String?
    let servingSize: Double
    let servingUnit: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?

    enum CodingKeys: String, CodingKey {
        case name, brand, calories
        case sourceType = "source_type"
        case externalId = "external_id"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
    }
}

struct NutritionLogCreatePayload: Codable {
    let foodItemId: String
    let quantity: Double
    let quantityUnit: String
    let mealType: String?
    let loggedAt: String

    enum CodingKeys: String, CodingKey {
        case quantity
        case foodItemId = "food_item_id"
        case quantityUnit = "quantity_unit"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
    }
}

struct NutritionLogUpdatePayload: Codable {
    let quantity: Double
    let quantityUnit: String
    let mealType: String?

    enum CodingKeys: String, CodingKey {
        case quantity
        case quantityUnit = "quantity_unit"
        case mealType = "meal_type"
    }
}

struct NutritionLogRecord: Codable, Identifiable {
    let id: String
    let foodItem: FoodItem
    let quantity: Double
    let quantityUnit: String
    let mealType: String?
    let loggedAt: String

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case foodItem = "food_item"
        case quantityUnit = "quantity_unit"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
    }

    /// Nutrition scales linearly from the food item's reference serving.
    var calorieContribution: Double { foodItem.calories * (quantity / foodItem.servingSize) }
    var proteinContribution: Double { foodItem.proteinG * (quantity / foodItem.servingSize) }
    var carbsContribution: Double { foodItem.carbsG * (quantity / foodItem.servingSize) }
    var fatContribution: Double { foodItem.fatG * (quantity / foodItem.servingSize) }
}

/// A search result from Open Food Facts, called directly from the app
/// (public API, no key needed) - not our backend.
struct OpenFoodFactsProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double

    func asCreatePayload() -> FoodItemCreatePayload {
        FoodItemCreatePayload(
            name: name,
            brand: brand,
            sourceType: "search",
            externalId: id,
            servingSize: 100,
            servingUnit: "g",
            calories: caloriesPer100g,
            proteinG: proteinPer100g,
            carbsG: carbsPer100g,
            fatG: fatPer100g,
            fiberG: nil,
            sugarG: nil,
            sodiumMg: nil
        )
    }
}
