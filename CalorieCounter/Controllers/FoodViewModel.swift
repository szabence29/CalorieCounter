import Foundation
import SwiftData
import Network

// MARK: - Spoonacular DTO-k

private struct IngredientSearchResponse: Decodable {
    let results: [IngredientResult]
    let totalResults: Int?
}

private struct IngredientResult: Decodable {
    let id: Int
    let name: String
    let image: String?
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

// MARK: - ViewModel (async/await, soros dúsítás, 429-kezelés)

@MainActor
final class FoodViewModel: ObservableObject {

    // UI state
    @Published var items: [APIFoodItem] = []
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var isOnline = true

    // API
    private let apiKey = "d6b322b71b24422b83d4e9ee299d6d8f"     // vidd .xcconfig-be
    private let baseURL = URL(string: "https://api.spoonacular.com")!

    // Keresési beállítások
    private let pageSize = 100

    // Hálózatfigyelés
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "net.monitor", qos: .utility)

    // Cancel a futó keresésre/dúsításra
    private var currentTask: Task<Void, Never>?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = (path.status == .satisfied)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
        currentTask?.cancel()
    }

    // MARK: - Public API (kompatibilis a nézetekkel)

    func fetchFoods(query: String = "") {
        fetchFoodsPaginated(query: query, pages: 1)
    }

    /// A ManualAddView ezt hívja – API kompatibilitás megtartva. :contentReference[oaicite:2]{index=2}
    func fetchFoodsPaginated(query: String, pages: Int = 1) {
        currentTask?.cancel()
        lastError = nil

        // Fire-and-forget Task, a hívó felé nem kell async interface
        currentTask = Task { [weak self] in
            guard let self else { return }
            await self._fetchFoodsPaginated(query: query, pages: pages)
        }
    }

    func saveToDatabase(item: APIFoodItem, context: ModelContext) {
        context.insert(item.toFoodItem())
    }

    // MARK: - Implementáció

    private func _fetchFoodsPaginated(query: String, pages: Int) async {
        guard isOnline else {
            self.lastError = "Offline – ellenőrizd a hálózatot."
            return
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.items = []
            self.isLoading = false
            return
        }

        isLoading = true
        lastError = nil

        do {
            // 1) keresési oldalak lekérése
            let pageCount = max(1, pages)
            let results = try await loadSearchPages(query: trimmed, pages: pageCount)

            if Task.isCancelled { return }

            // 2) light lista felrajzolása (kép + név, kcal = nil)
            let light = mapLight(results: results)
            self.items = dedupeBySpoonId(light)
                .sorted { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }

            if Task.isCancelled { return }

            // 3) dúsítás sorosan, 429-et kezelve
            let ids = Array(Set(results.map(\.id)))
            await enrichSequential(ids: ids)

            isLoading = false
        } catch {
            if Task.isCancelled { return }
            self.isLoading = false
            self.lastError = error.localizedDescription
        }
    }

    // MARK: - Search

    private func loadSearchPages(query: String, pages: Int) async throws -> [IngredientResult] {
        var out: [IngredientResult] = []
        for page in 0..<pages {
            try Task.checkCancellation()
            let offset = page * pageSize
            let url = baseURL
                .appending(path: "/food/ingredients/search")
                .appending(queryItems: [
                    .init(name: "query", value: query),
                    .init(name: "number", value: String(pageSize)),
                    .init(name: "offset", value: String(offset)),
                    .init(name: "metaInformation", value: "true"),
                    .init(name: "apiKey", value: apiKey)
                ])

            let (data, response) = try await URLSession.shared.data(from: url)
            try response.ensureOK()
            let decoded = try JSONDecoder().decode(IngredientSearchResponse.self, from: data)
            out.append(contentsOf: decoded.results)
        }
        return out
    }

    private func mapLight(results: [IngredientResult]) -> [APIFoodItem] {
        results.map { r in
            let imgURL = r.image.flatMap {
                URL(string: "https://img.spoonacular.com/ingredients_250x250/\($0)")
            }
            return APIFoodItem(
                spoonId: r.id,
                name: r.name,
                servingSize: 100,
                servingSizeUnit: "g",
                energyKcal: nil,                 // „—” a listában
                protein_g: nil,
                fat_total_g: nil,
                carbohydrates_total_g: nil,
                fiber_g: nil,
                sugar_g: nil,
                foodCategory: nil,
                imageUrl: imgURL
            )
        }
    }

    // MARK: - Enrichment (sequential + retry/backoff 429-re)

    private func enrichSequential(ids: [Int]) async {
        // kis lépésköz a kérések között (kíméli a rate limitet)
        let baseGap: TimeInterval = 0.25

        for (idx, id) in ids.enumerated() {
            if Task.isCancelled { return }

            do {
                let info = try await fetchInfoWithRetry(id: id, maxAttempts: 3)
                let nutrients = info.nutrition.nutrients
                let kcal    = nutrients.first(where: { $0.name == "Calories" })?.amount ?? 0
                let protein = nutrients.first(where: { $0.name == "Protein" })?.amount ?? 0
                let fat     = nutrients.first(where: { $0.name == "Fat" })?.amount ?? 0
                let carbs   = nutrients.first(where: { $0.name == "Carbohydrates" })?.amount ?? 0
                let fiber   = nutrients.first(where: { $0.name == "Fiber" })?.amount
                let sugar   = nutrients.first(where: { $0.name == "Sugar" })?.amount

                let imgURL = info.image.flatMap {
                    URL(string: "https://img.spoonacular.com/ingredients_500x500/\($0)")
                }

                let enriched = APIFoodItem(
                    spoonId: info.id,
                    name: info.name,
                    servingSize: info.amount ?? 100,
                    servingSizeUnit: info.unit ?? "g",
                    energyKcal: Int(kcal.rounded()),
                    protein_g: protein,
                    fat_total_g: fat,
                    carbohydrates_total_g: carbs,
                    fiber_g: fiber,
                    sugar_g: sugar,
                    foodCategory: nil,
                    imageUrl: imgURL
                )

                // Per-sor frissítés (szebb UX)
                applyRowUpdate(enriched)

            } catch {
                // 429 vagy más hiba után lépjünk tovább; a light sor marad „—”-on
                // (Ha akarsz, ide tehetsz loggolást.)
            }

            // alap gap (ha Retry-After volt, azt a fetchInfoWithRetry már kivárta)
            try? await Task.sleep(nanoseconds: UInt64(baseGap * 1_000_000_000))
            // kis ritkítás nagy listán
            if idx % 50 == 0 { try? await Task.sleep(nanoseconds: 50_000_000) }
        }
    }

    private func fetchInfoWithRetry(id: Int, maxAttempts: Int) async throws -> IngredientInfoResponse {
        var attempt = 0
        var lastError: Error?

        while attempt < maxAttempts {
            try Task.checkCancellation()
            do {
                let (data, response) = try await URLSession.shared.data(from: infoURL(id: id))
                if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                    // Rate limited – várjunk Retry-After-t, vagy exponenciális backoffot
                    let wait = http.retryAfter ?? pow(2.0, Double(attempt)) * 0.8
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    attempt += 1
                    continue
                }
                try response.ensureOK()
                return try JSONDecoder().decode(IngredientInfoResponse.self, from: data)
            } catch {
                lastError = error
                attempt += 1
                // kis backoff
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 0.3 * 1_000_000_000))
            }
        }
        throw lastError ?? URLError(.badServerResponse)
    }

    private func infoURL(id: Int) -> URL {
        baseURL
            .appending(path: "/food/ingredients/\(id)/information")
            .appending(queryItems: [
                .init(name: "amount", value: "100"),
                .init(name: "unit", value: "gram"),
                .init(name: "apiKey", value: apiKey)
            ])
    }

    // MARK: - Helpers

    private func dedupeBySpoonId(_ array: [APIFoodItem]) -> [APIFoodItem] {
        var seen = Set<Int>()
        var out: [APIFoodItem] = []
        out.reserveCapacity(array.count)
        for x in array where seen.insert(x.spoonId).inserted {
            out.append(x)
        }
        return out
    }

    /// Per-sor frissítés: ha megjött a dúsított elem, cseréljük a helyén.
    private func applyRowUpdate(_ item: APIFoodItem) {
        if let idx = items.firstIndex(where: { $0.spoonId == item.spoonId }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        items.sort { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }
    }
}

// MARK: - URL & HTTP helpers

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        comps.queryItems = (comps.queryItems ?? []) + queryItems
        return comps.url!
    }
}

private extension URLResponse {
    func ensureOK() throws {
        guard let http = self as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private extension HTTPURLResponse {
    var retryAfter: TimeInterval? {
        // Retry-After (seconds vagy HTTP-date); itt csak seconds-t kezelünk
        if let v = allHeaderFields["Retry-After"] as? String, let sec = TimeInterval(v) {
            return sec
        }
        return nil
    }
}
