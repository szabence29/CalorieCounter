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
    let image: String?
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
    @Published var isLoading = false
    @Published var lastError: String?

    // 🔑 VIDD .xcconfig-be
    private let apiKey = "d6b322b71b24422b83d4e9ee299d6d8f"
    private let baseURL = "https://api.spoonacular.com"

    private let session = Session.default
    private var currentRequests: [DataRequest] = []

    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    // EGYOLDALAS KERESÉS (ha ragaszkodsz hozzá)
    func fetchFoods(query: String = "") {
        cancelInFlight()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { self.items = []; return }

        let url = "\(baseURL)/food/ingredients/search"
        let params: Parameters = [
            "query": trimmed,
            "number": 100,
            "offset": 0,
            "sort": "popularity",
            "metaInformation": true,
            "apiKey": apiKey
        ]

        let req = session.request(url, parameters: params)
            .validate()
            .responseDecodable(of: IngredientSearchResponse.self) { [weak self] response in
                guard let self = self else { return }
                switch response.result {
                case .success(let search):
                    self.collectNutrition(for: search.results.map(\.id)) { collected in
                        self.items = self.dedupeByFdcId(collected)
                            .sorted { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }
                    }
                case .failure(let error):
                    print("Search failed:", error)
                    self.items = []
                }
            }
        currentRequests.append(req)
    }

    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    // LAPOZÓS (PAGINATED) KERESÉS – stabil, több találat
    private let pageSize = 100

    /// Több oldalt kér le (0, 100, 200, …) és összefűzi.
    /// pages: hány oldalt kérjen (1 oldal = 100 találat a Spoonacularnál).
    func fetchFoodsPaginated(query: String, pages: Int = 3) {
        cancelInFlight()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { self.items = []; return }

        let outerGroup = DispatchGroup()
        var allItemsThreadUnsafe: [APIFoodItem] = []
        let lock = NSLock()

        for page in 0..<max(1, pages) {
            let offset = page * pageSize
            outerGroup.enter()
            fetchSearchPage(query: trimmed, offset: offset, number: pageSize) { pageItems in
                lock.lock()
                allItemsThreadUnsafe.append(contentsOf: pageItems)
                lock.unlock()
                outerGroup.leave()
            }
        }

        outerGroup.notify(queue: .main) {
            // dedupe + rendezés
            let merged = self.dedupeByFdcId(allItemsThreadUnsafe)
                .sorted { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }
            self.items = merged
        }
    }

    /// Egyetlen oldal lekérése + azon a nutrition részletek begyűjtése (NINCS limit – figyelj a kvótára!)
    private func fetchSearchPage(
        query: String,
        offset: Int,
        number: Int,
        completion: @escaping ([APIFoodItem]) -> Void
    ) {
        let url = "\(baseURL)/food/ingredients/search"
        let params: Parameters = [
            "query": query,
            "number": number,
            "offset": offset,
            "sort": "popularity",
            "metaInformation": true,
            "apiKey": apiKey
        ]

        let req = session.request(url, parameters: params)
            .validate()
            .responseDecodable(of: IngredientSearchResponse.self) { [weak self] response in
                guard let self = self else { completion([]); return }
                switch response.result {
                case .success(let search):
                    let ids = search.results.map { $0.id }
                    self.collectNutrition(for: ids, completion: completion)
                case .failure(let error):
                    print("Search page failed (offset \(offset)):", error)
                    completion([])
                }
            }
        currentRequests.append(req)
    }

    /// Több id nutrition adatát begyűjti és visszaadja APIFoodItem tömbként
    private func collectNutrition(for ids: [Int], completion: @escaping ([APIFoodItem]) -> Void) {
        guard !ids.isEmpty else { completion([]); return }

        let group = DispatchGroup()
        var temp: [APIFoodItem] = []
        let lock = NSLock()

        for id in ids {
            group.enter()
            fetchNutrition(for: id) { item in
                if let item {
                    lock.lock(); temp.append(item); lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(temp)
        }
    }

    // MARK: - SwiftData mentés

    func saveToDatabase(item: APIFoodItem, context: ModelContext) {
        context.insert(item.toFoodItem())
    }

    // MARK: - Private helpers

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
                    let n = info.nutrition.nutrients
                    let kcal   = n.first(where: { $0.name == "Calories" })?.amount ?? 0
                    let protein = n.first(where: { $0.name == "Protein" })?.amount ?? 0
                    let fat     = n.first(where: { $0.name == "Fat" })?.amount ?? 0
                    let carbs   = n.first(where: { $0.name == "Carbohydrates" })?.amount ?? 0
                    let fiber   = n.first(where: { $0.name == "Fiber" })?.amount
                    let sugar   = n.first(where: { $0.name == "Sugar" })?.amount

                    let imgURL = info.image.flatMap {
                        URL(string: "https://img.spoonacular.com/ingredients_500x500/\($0)")
                    }

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
                        sugar_g: sugar,
                        foodCategory: nil,
                        imageUrl: imgURL
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

    private func dedupeByFdcId(_ array: [APIFoodItem]) -> [APIFoodItem] {
        var seen = Set<Int>()
        var out: [APIFoodItem] = []
        out.reserveCapacity(array.count)
        for x in array where seen.insert(x.fdcId).inserted {
            out.append(x)
        }
        return out
    }

    // Meghagyhatod, ha valahol még használod:
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

// Ha már nincs szükséged a csoportosításra, ezt elhagyhatod.
// Meghagytam kommentben, hogy ne törje meg a régi hivatkozás.
//extension FoodViewModel {
//    var groupedByName: [FoodGroup] { [] }
//}
