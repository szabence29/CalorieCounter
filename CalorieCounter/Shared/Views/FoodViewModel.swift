import Foundation
import Combine
import SwiftData
import Alamofire

struct FoodResponse: Decodable {
    let foods: [APIFoodItem]
    let totalHits: Int
}

struct APIFoodItem: Identifiable, Decodable {
    let fdcId: Int
    let description: String
    var id: Int { fdcId }
    
    /// Pl. "Agave, raw (Southwest)" -> "Agave"
    var primaryName: String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstChunk = trimmed.split(separator: ",").first {
            return String(firstChunk)
        }
        // Fallback: első szó
        return String(trimmed.split(separator: " ").first ?? Substring(trimmed))
    }
    
    func toFoodItem() -> FoodItem {
        FoodItem(fdcId: fdcId, description: description)
    }
}

final class FoodViewModel: ObservableObject {
    @Published var items: [APIFoodItem] = []
    private let apiKey = "MVRBUXmFhU6vD1tD3VURDkHvKieOdfHEkXfutOfh"
    
    // Csoportok a List-hez: ABC szerint rendezett szekciók
    var groupedSections: [(key: String, value: [APIFoodItem])] {
        let grouped = Dictionary(grouping: items, by: { $0.primaryName })
        let sortedKeys = grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return sortedKeys.map { key in
            let values = (grouped[key] ?? []).sorted { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }
            return (key, values)
        }
    }
    
    private let session = Session.default
    private var currentRequest: DataRequest?
    
    func fetchFoods(query: String = "") {
        currentRequest?.cancel()
        let url = "https://api.nal.usda.gov/fdc/v1/foods/search"
        let params: Parameters = ["query": query, "pageSize": 200, "api_key": apiKey]
        
        currentRequest = session.request(url, parameters: params)
            .validate()
            .responseDecodable(of: FoodResponse.self) { [weak self] response in
                switch response.result {
                case .success(let r): self?.items = r.foods
                case .failure:        self?.items = []
                }
            }
    }
    
    func saveToDatabase(item: APIFoodItem, context: ModelContext) {
        context.insert(item.toFoodItem())
    }
}
