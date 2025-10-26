import Foundation

struct APIFoodItem: Identifiable, Decodable {
    let fdcId: Int
    let description: String
    var id: Int { fdcId }

    // hasznos opcionális mezők a Search response-ból
    let brandOwner: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let foodNutrients: [APINutrient]?

    // plusz meta a “basic” finomításhoz
    let dataType: String?        // "Survey (FNDDS)" | "Foundation" | "SR Legacy" | "Branded"
    let foodCategory: String?    // pl. "Fruits and Fruit Juices", "Vegetables and Vegetable Products"

    struct APINutrient: Decodable {
        let nutrientName: String?
        let unitName: String?
        let value: Double?
    }

    /// Pl. "Agave, raw (Southwest)" -> "Agave"
    var primaryName: String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstChunk = trimmed.split(separator: ",").first {
            return String(firstChunk)
        }
        return String(trimmed.split(separator: " ").first ?? Substring(trimmed))
    }

    /// Kcal az Energy (kcal) tápanyagból (ha van)
    var energyKcal: Int? {
        guard let n = foodNutrients?
            .first(where: { ($0.nutrientName ?? "").localizedCaseInsensitiveContains("energy")
                         && ($0.unitName ?? "").localizedCaseInsensitiveContains("kcal") }),
              let v = n.value else { return nil }
        return Int(v.rounded())
    }

    /// "1 cup" / "100 g" stb.
    var servingLine: String {
        if let s = servingSize, let u = servingSizeUnit, s > 0 {
            let sText = (s == floor(s)) ? String(Int(s)) : String(s)
            return "\(sText) \(u.lowercased())"
        }
        return ""
    }

    func toFoodItem() -> FoodItem {   // SwiftData entitássá alakítás
        FoodItem(fdcId: fdcId, description: description)
    }
}
