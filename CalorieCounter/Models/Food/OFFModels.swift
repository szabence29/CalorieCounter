import Foundation

struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
    let count: Int?
    let page: Int?
    let page_size: Int?
}

struct OFFProduct: Decodable, Identifiable {
    let code: String                 // EAN/UPC, pl. "599..."
    let product_name: String?
    let product_name_en: String?
    let brands: String?
    let nutriments: Nutriments?

    var id: String { code }

    struct Nutriments: Decodable {
        let energy_kcal_100g: Double?
        let proteins_100g: Double?
        let carbohydrates_100g: Double?
        let sugars_100g: Double?
        let fat_100g: Double?
        let saturated_fat_100g: Double?
        let fiber_100g: Double?
        let salt_100g: Double?
    }

    /// Preferált megjelenítési név (HU → EN → márka → vonalkód)
    var displayName: String {
        product_name_en?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        ?? product_name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        ?? brands?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        ?? code
    }
}

extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }
}
