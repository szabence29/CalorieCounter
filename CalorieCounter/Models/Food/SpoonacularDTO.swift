import Foundation

// Spoonacular DTO-k (az endpointok JSON-jeihez 1:1).
struct IngredientSearchResponse: Decodable {
    let results: [IngredientResult]
    let totalResults: Int?
}

struct IngredientResult: Decodable {
    let id: Int
    let name: String
    let image: String?
}

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
