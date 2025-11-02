import Foundation
import SwiftData

/// Spoonacular-ból felépített modell, amely megtartja a korábbi (USDA-s) API-hoz igazodó property-ket,
/// hogy a UI-hoz ne kelljen hozzányúlni.
struct APIFoodItem: Identifiable, Decodable {
    // ✅ A UI és a deduplikáció miatt megtartjuk ezeket az aliasokat
    let fdcId: Int              // alias: Spoonacular id
    let description: String     // alias: ingredient name
    var id: Int { fdcId }

    // Opcionális mezők a UI-hoz (megtartjuk az interfészt)
    let brandOwner: String? = nil
    let servingSize: Double?
    let servingSizeUnit: String?
    let foodNutrients: [APINutrient]? = nil

    // Meta – a régi heurisztikához
    let dataType: String? = "Spoonacular"
    let foodCategory: String?   // pl. "fruit" (ha lesz kategória)

    // Makrók
    let energyKcalValue: Int?
    let protein_g: Double?
    let fat_total_g: Double?
    let carbohydrates_total_g: Double?
    let fiber_g: Double?
    let sugar_g: Double?

    // ⬇️ ÚJ: kép URL a Spoonacular CDN-re
    let imageUrl: URL?

    // Dummy a régi API-hoz igazodva (nem használjuk most)
    struct APINutrient: Decodable {
        let nutrientName: String?
        let unitName: String?
        let value: Double?
    }

    // MARK: - Kézreálló computed-ek a meglévő UI-hoz

    var primaryName: String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstChunk = trimmed.split(separator: ",").first {
            return String(firstChunk)
        }
        return String(trimmed.split(separator: " ").first ?? Substring(trimmed))
    }

    var energyKcal: Int? { energyKcalValue }

    var servingLine: String {
        if let s = servingSize, let u = servingSizeUnit, s > 0 {
            let sText = (s == floor(s)) ? String(Int(s)) : String(s)
            return "\(sText) \(u.lowercased())"
        }
        return ""
    }

    // MARK: - Spoonacular initializer

    init(
        spoonId: Int,
        name: String,
        servingSize: Double,
        servingSizeUnit: String,
        energyKcal: Int,
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

    // SwiftData entitássá alakítás – megtartjuk a régi sémát
    func toFoodItem() -> FoodItem {
        FoodItem(fdcId: fdcId, description: description)
    }
}
