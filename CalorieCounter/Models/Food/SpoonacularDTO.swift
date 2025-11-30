import Foundation

/// /food/ingredients/search válasz
struct IngredientSearchResponse: Decodable {
    let results: [IngredientResult]
    let totalResults: Int?
}

/// Egy keresési találat (light adat)
struct IngredientResult: Decodable {
    let id: Int
    let name: String
    let image: String?
}

/// /food/ingredients/{id}/information válasz
struct IngredientInfoResponse: Decodable {
    let id: Int
    let name: String
    let amount: Double?
    let unit: String?
    let nutrition: NutritionInfo
    let image: String?
}

struct NutritionInfo: Decodable {
    let nutrients: [Nutrient]
}

struct Nutrient: Decodable {
    let name: String
    let amount: Double
    let unit: String
}
