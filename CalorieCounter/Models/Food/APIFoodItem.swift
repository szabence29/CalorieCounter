import Foundation
import SwiftData

// UI-kompatibilis “API food” modell: Spoonacularból jön
struct APIFoodItem: Identifiable, Decodable {
    // Spoonacular azonosító – több néven is elérhető a kódban (UI/VM kompat miatt).
    let fdcId: Int
    var id: Int { fdcId }
    var spoonId: Int { fdcId }

    let description: String

    // Régi UI miatt itt hagyott, de Spoonacularból tipikusan nincs/ nem használjuk.
    let brandOwner: String? = nil
    let servingSize: Double?
    let servingSizeUnit: String?
    let foodNutrients: [APINutrient]? = nil

    let dataType: String? = "Spoonacular"
    let foodCategory: String?

    // “Light” rekordnál ezek még lehetnek nil-ek, később dúsítjuk.
    let energyKcalValue: Int?
    let protein_g: Double?
    let fat_total_g: Double?
    let carbohydrates_total_g: Double?
    let fiber_g: Double?
    let sugar_g: Double?

    let imageUrl: URL?

    struct APINutrient: Decodable {
        let nutrientName: String?
        let unitName: String?
        let value: Double?
    }

    // MARK: - UI helper-ek

    var primaryName: String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstChunk = trimmed.split(separator: ",").first { return String(firstChunk) }
        return String(trimmed.split(separator: " ").first ?? Substring(trimmed))
    }

    var energyKcal: Int? { energyKcalValue }

    var servingLine: String {
        guard let s = servingSize, let u = servingSizeUnit, s > 0 else { return "" }
        let sText = (s == floor(s)) ? String(Int(s)) : String(s)
        return "\(sText) \(u.lowercased())"
    }

    // MARK: - Spoonacular -> APIFoodItem

    init(
        spoonId: Int,
        name: String,
        servingSize: Double,
        servingSizeUnit: String,
        energyKcal: Int?,
        protein_g: Double?,
        fat_total_g: Double?,
        carbohydrates_total_g: Double?,
        fiber_g: Double?,
        sugar_g: Double?,
        foodCategory: String? = nil,
        imageUrl: URL? = nil
    ) {
        self.fdcId = spoonId
        self.description = name
        self.servingSize = servingSize
        self.servingSizeUnit = servingSizeUnit
        self.energyKcalValue = energyKcal
        self.protein_g = protein_g
        self.fat_total_g = fat_total_g
        self.carbohydrates_total_g = carbohydrates_total_g
        self.fiber_g = fiber_g
        self.sugar_g = sugar_g
        self.foodCategory = foodCategory
        self.imageUrl = imageUrl
    }

    /// SwiftData entitás: itt csak a minimál mezőket tároljuk (a többi “snapshot” a naplóba kerül).
    func toFoodItem() -> FoodItem {
        FoodItem(fdcId: fdcId, description: description)
    }
}
