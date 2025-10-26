import Foundation
import Combine
import SwiftData
import Alamofire

// MARK: - API response

struct FoodResponse: Decodable {
    let foods: [APIFoodItem]
    let totalHits: Int
}

// MARK: - ViewModel

final class FoodViewModel: ObservableObject {
    @Published var items: [APIFoodItem] = []

    // TODO: vidd .xcconfig / env-be
    private let apiKey = "MVRBUXmFhU6vD1tD3VURDkHvKieOdfHEkXfutOfh"

    private let session = Session.default
    private var currentRequests: [DataRequest] = []

    /// USDA keresés
    /// - Üres query: teljes adattár (Branded is), több oldal
    /// - Keresés: teljes adattár, több oldal, egész-szó (majd szükség szerint contains) szűrés
    func fetchFoods(query: String = "") {
        cancelInFlight()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            // ÜRES → töltsünk be sok mindent
            fetchMultiplePages(
                query: "",
                dataTypes: "Branded,Survey (FNDDS),Foundation,SR Legacy",
                pages: 5,
                pageSize: 200
            ) { [weak self] all in
                guard let self = self else { return }
                self.items = self.dedupeByFdcId(all)
            }
        } else {
            // KERESÉS → teljes adattár
            fetchMultiplePages(
                query: trimmed,
                dataTypes: "Branded,Survey (FNDDS),Foundation,SR Legacy",
                pages: 3,
                pageSize: 200
            ) { [weak self] results in
                guard let self = self else { return }
                let filtered = self.wordMatchFilter(results, needle: trimmed)
                self.items = self.dedupeByFdcId(filtered)
            }
        }
    }

    // SwiftData mentés
    func saveToDatabase(item: APIFoodItem, context: ModelContext) {
        context.insert(item.toFoodItem())
    }

    // MARK: - Networking helpers

    /// Lapozva több oldalt kér le és fűz össze.
    private func fetchMultiplePages(
        query: String,
        dataTypes: String,
        pages: Int,
        pageSize: Int,
        completion: @escaping ([APIFoodItem]) -> Void
    ) {
        let url = "https://api.nal.usda.gov/fdc/v1/foods/search"
        var aggregated: [APIFoodItem] = []
        var remaining = pages

        func get(page: Int) {
            let params: Parameters = [
                "query": query,
                "dataType": dataTypes,
                "pageNumber": page,
                "pageSize": pageSize,
                "api_key": apiKey
            ]
            let req = session.request(url, parameters: params)
                .validate()
                .responseDecodable(of: FoodResponse.self) { [weak self] response in
                    guard let self = self else { return }

                    if case .success(let r) = response.result {
                        aggregated.append(contentsOf: r.foods)
                    }
                    remaining -= 1
                    if remaining == 0 {
                        completion(aggregated)
                    } else {
                        get(page: page + 1)
                    }
                }
            currentRequests.append(req)
        }

        get(page: 1)
    }

    private func cancelInFlight() {
        currentRequests.forEach { $0.cancel() }
        currentRequests.removeAll()
    }

    /// Duplikátumok kiszűrése fdcId alapján
    private func dedupeByFdcId(_ array: [APIFoodItem]) -> [APIFoodItem] {
        var seen = Set<Int>()
        var out: [APIFoodItem] = []
        out.reserveCapacity(array.count)
        for x in array where seen.insert(x.fdcId).inserted {
            out.append(x)
        }
        return out
    }

    /// Egész-szó egyezés, ha túl kevés találat → lazítás `contains`-re
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

// MARK: - Csoportosítás a listanézethez

struct FoodGroup: Identifiable {
    let id = UUID()
    let name: String
    let items: [APIFoodItem]

    var representative: APIFoodItem? {
        items.min(by: { basicScore(for: $0) < basicScore(for: $1) })
    }
    var count: Int { items.count }

    var kcalRangeText: String {
        let kcals = items.compactMap { $0.energyKcal }
        guard let min = kcals.min(), let max = kcals.max() else { return "— cal" }
        return (min == max) ? "\(min) cal" : "\(min)–\(max) cal"
    }

    var servingSample: String {
        if let r = representative, !(r.servingLine.isEmpty) { return r.servingLine }
        return items.first?.servingLine.isEmpty == false ? (items.first?.servingLine ?? "") : ""
    }
}

extension FoodViewModel {
    var groupedByName: [FoodGroup] {
        let dict = Dictionary(grouping: items) { item in
            item.primaryName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        return dict
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { _, values in
                let sorted = values.sorted {
                    $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending
                }
                return FoodGroup(name: sorted.first?.primaryName ?? "", items: sorted)
            }
    }
}

// MARK: - Heurisztika a reprezentáns kiválasztásához

private func basicScore(for item: APIFoodItem) -> Int {
    var score = 0
    switch item.dataType?.lowercased() {
    case "foundation"?, "sr legacy"?: score -= 3
    case "survey (fndds)"?: score -= 1
    default: break
    }
    if item.brandOwner == nil { score -= 3 }
    if let u = item.servingSizeUnit?.lowercased(), let s = item.servingSize {
        if (u == "g" || u == "gram" || u == "ml"), (80...200).contains(s) { score -= 2 }
    }
    let noise = ["sauce","sandwich","soup","casserole","dressing","alfredo","marinara","burger","pizza"]
    let text = item.description.lowercased()
    score += noise.reduce(0) { $0 + (text.contains($1) ? 2 : 0) }
    score += max(0, text.split(separator: " ").count - 3)
    return score
}
