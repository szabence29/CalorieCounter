import Foundation
import Combine
import Alamofire
import SwiftData

// MARK: - Spoonacular response DTO-k

private struct IngredientSearchResponse: Decodable {
    let results: [IngredientResult]
    let totalResults: Int?
}
private struct IngredientResult: Decodable {
    let id: Int
    let name: String
}

private struct IngredientInfoResponse: Decodable {
    let id: Int
    let name: String
    let amount: Double?
    let unit: String?
    let nutrition: NutritionInfo
}
private struct NutritionInfo: Decodable {
    let nutrients: [Nutrient]
}
private struct Nutrient: Decodable {
    let name: String
    let amount: Double
    let unit: String
}

// MARK: - ViewModel – Spoonacular integráció

final class FoodViewModel: ObservableObject {
    @Published var items: [APIFoodItem] = []

    // 🔑 VIDD .xcconfig-be
    private let apiKey = "d6b322b71b24422b83d4e9ee299d6d8f"
    private let baseURL = "https://api.spoonacular.com"

    private let session = Session.default
    private var currentRequests: [DataRequest] = []

    /// Spoonacular keresés név alapján, majd minden találathoz betöltjük a tápértéket 100 g-ra.
    func fetchFoods(query: String = "") {
        cancelInFlight()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Üres keresésnél ne terheljük az API-t – üres lista
            self.items = []
            return
        }

        let url = "\(baseURL)/food/ingredients/search"
        let params: Parameters = [
            "query": trimmed,
            "number": 10,            // hány találatból kérjünk részleteket
            "apiKey": apiKey
        ]

        let req = session.request(url, parameters: params)
            .validate()
            .responseDecodable(of: IngredientSearchResponse.self) { [weak self] response in
                guard let self = self else { return }
                switch response.result {
                case .success(let search):
                    if search.results.isEmpty {
                        self.items = []
                        return
                    }
                    // minden találathoz nutrition lekérés
                    let group = DispatchGroup()
                    var temp: [APIFoodItem] = []
                    for r in search.results {
                        group.enter()
                        self.fetchNutrition(for: r.id) { item in
                            if let item = item { temp.append(item) }
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) {
                        // csoportosításnál stabil listát adunk
                        self.items = self.dedupeByFdcId(temp)
                    }
                case .failure(let error):
                    print("Search failed:", error)
                    self.items = []
                }
            }
        currentRequests.append(req)
    }

    /// Vonalkód (UPC) alapú lekérés – opcionális helper
    func fetchByBarcode(_ upc: String) {
        cancelInFlight()
        let url = "\(baseURL)/food/products/upc"
        let params: Parameters = [
            "upc": upc,
            "apiKey": apiKey
        ]
        let req = session.request(url, parameters: params)
            .validate()
            .responseJSON { [weak self] resp in
                guard let self = self else { return }
                // A Spoonacular products UPC válasza eltérő szerkezetű lehet.
                // Itt demonstratív jelleggel üresítjük a listát, vagy át_mappingolhatod saját igény szerint.
                // Javaslat: products -> nutrition -> nutrients alapján ugyanúgy összeállítható egy APIFoodItem.
                switch resp.result {
                case .success:
                    // TODO: implementáld, ha UPC kell
                    self.items = []
                case .failure(let error):
                    print("UPC fetch failed:", error)
                    self.items = []
                }
            }
        currentRequests.append(req)
    }

    // MARK: - SwiftData mentés

    func saveToDatabase(item: APIFoodItem, context: ModelContext) {
        context.insert(item.toFoodItem())
    }

    // MARK: - Private

    private func fetchNutrition(for id: Int, completion: @escaping (APIFoodItem?) -> Void) {
        let url = "\(baseURL)/food/ingredients/\(id)/information"
        let params: Parameters = [
            "amount": 100,
            "unit": "gram",
            "apiKey": apiKey
        ]

        let req = session.request(url, parameters: params)
            .validate()
            .responseDecodable(of: IngredientInfoResponse.self) { response in
                switch response.result {
                case .success(let info):
                    // Kinyerjük a fő makrókat a nutrients tömbből
                    let n = info.nutrition.nutrients
                    let kcal = n.first(where: { $0.name == "Calories" })?.amount ?? 0
                    let protein = n.first(where: { $0.name == "Protein" })?.amount ?? 0
                    let fat = n.first(where: { $0.name == "Fat" })?.amount ?? 0
                    let carbs = n.first(where: { $0.name == "Carbohydrates" })?.amount ?? 0
                    let fiber = n.first(where: { $0.name == "Fiber" })?.amount
                    let sugar = n.first(where: { $0.name == "Sugar" })?.amount

                    // A régi UI által használt mezők „USDA-kompatibilis” aliasokkal
                    let item = APIFoodItem(
                        spoonId: info.id,
                        name: info.name,
                        servingSize: info.amount ?? 100,
                        servingSizeUnit: (info.unit ?? "g"),
                        energyKcal: Int(kcal.rounded()),
                        protein_g: protein,
                        fat_total_g: fat,
                        carbohydrates_total_g: carbs,
                        fiber_g: fiber,
                        sugar_g: sugar
                    )
                    completion(item)
                case .failure(let error):
                    print("Nutrition fetch failed:", error)
                    completion(nil)
                }
            }
        currentRequests.append(req)
    }

    private func cancelInFlight() {
        currentRequests.forEach { $0.cancel() }
        currentRequests.removeAll()
    }

    /// A régi logika miatt megtartjuk – Spoonacular id alapján deduplikálunk (alias fdcId).
    private func dedupeByFdcId(_ array: [APIFoodItem]) -> [APIFoodItem] {
        var seen = Set<Int>()
        var out: [APIFoodItem] = []
        out.reserveCapacity(array.count)
        for x in array where seen.insert(x.fdcId).inserted {
            out.append(x)
        }
        return out
    }

    /// Meghagyjuk – a leírás (description = name) alapján működik tovább.
    private func wordMatchFilter(_ items: [APIFoodItem], needle: String) -> [APIFoodItem] {
        let n = needle.lowercased()
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: n) + "\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let strict = items.filter { item in
                let s = item.description
                let r = NSRange(location: 0, length: s.utf16.count)
                return regex.firstMatch(in: s, options: [], range: r) != nil
            }
            if strict.count >= 30 { return strict }
        }
        return items.filter { $0.description.lowercased().contains(n) }
    }
}

// MARK: - Csoportosítás a listanézethez (Spoonacular-kompatibilis)

struct FoodGroup: Identifiable {
    let id = UUID()
    let name: String
    let items: [APIFoodItem]

    var representative: APIFoodItem? {
        items.first
    }
    var count: Int { items.count }

    var kcalRangeText: String {
        let kcals = items.compactMap { $0.energyKcal }
        guard let min = kcals.min(), let max = kcals.max() else { return "— cal" }
        return (min == max) ? "\(min) cal" : "\(min)–\(max) cal"
    }

    var servingSample: String {
        if let r = representative, !(r.servingLine.isEmpty) { return r.servingLine }
        return items.first?.servingLine ?? ""
    }
}

extension FoodViewModel {
    /// Régi USDA logikát megtartjuk: név alapján csoportosítjuk az itemeket.
    var groupedByName: [FoodGroup] {
        let dict = Dictionary(grouping: items) { item in
            item.primaryName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        return dict
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { key, values in
                let sorted = values.sorted {
                    $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending
                }
                return FoodGroup(name: key, items: sorted)
            }
    }
}
