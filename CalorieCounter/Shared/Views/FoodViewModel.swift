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
    @Published var items: [APIFoodItem] = [] //API-ből jövő ételek
    private let apiKey = "MVRBUXmFhU6vD1tD3VURDkHvKieOdfHEkXfutOfh" //API kulcs, de nem a legjobb helyen van. Később környezeti változóban lesz eltárolva.
    
    // Csoportok a List-hez: ABC szerint rendezett szekciók
    var groupedSections: [(key: String, value: [APIFoodItem])] {
        let grouped = Dictionary(grouping: items, by: { $0.primaryName })
        let sortedKeys = grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return sortedKeys.map { key in
            let values = (grouped[key] ?? []).sorted { $0.description.localizedCaseInsensitiveCompare($1.description) == .orderedAscending }
            return (key, values)
        }
    }
    
    //Alamofire session és aktuális kérés tárolása
    private let session = Session.default
    private var currentRequest: DataRequest?
    
    /// API hívás: ételek keresése
    func fetchFoods(query: String = "") {
        currentRequest?.cancel()
        //Endpoint és query paraméterek
        let url = "https://api.nal.usda.gov/fdc/v1/foods/search"
        let params: Parameters = [
            "query": query,
            "pageSize": 200,
            "api_key": apiKey
        ]
        
        currentRequest = session.request(url, parameters: params)
            .validate()
            .responseDecodable(of: FoodResponse.self) { [weak self] response in
                switch response.result {
                case .success(let r):
                    // Ha sikerült dekódolni, töltsük be az itemeket
                    self?.items = r.foods
                case .failure:
                    // Hiba esetén üres
                    self?.items = []
                }
            }
    }
    
    //SwiftData adatbázisba mentés (Ehhez a FoodItem modellnek egy perzisztens entitásnak kell lennie)
    func saveToDatabase(item: APIFoodItem, context: ModelContext) {
        context.insert(item.toFoodItem())
    }
}
