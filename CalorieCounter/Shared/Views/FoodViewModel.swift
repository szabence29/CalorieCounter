import Foundation
import Combine
import SwiftData

struct FoodResponse: Decodable {
    let foods: [APIFoodItem]
    let totalHits: Int
}

struct APIFoodItem: Identifiable, Decodable {
    let fdcId: Int
    let description: String
    var id: Int { fdcId }
    
    // Convert API model to SwiftData model
    func toFoodItem() -> FoodItem {
        return FoodItem(fdcId: fdcId, description: description)
    }
}

class FoodViewModel: ObservableObject {
    @Published var items: [APIFoodItem] = []
    private var cancellables = Set<AnyCancellable>()
    
    private let apiKey = "MVRBUXmFhU6vD1tD3VURDkHvKieOdfHEkXfutOfh"
    
    func fetchFoods(query: String = "") {
        let searchQuery = query.isEmpty ? "" : query
        let urlString = "https://api.nal.usda.gov/fdc/v1/foods/search?query=\(searchQuery)&pageSize=200&api_key=\(apiKey)"
        guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: FoodResponse.self, decoder: JSONDecoder())
            .map { $0.foods }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: &$items)
    }
    
    // Helper method to save an API item to the database
    func saveToDatabase(item: APIFoodItem, context: ModelContext) {
        let foodItem = item.toFoodItem()
        context.insert(foodItem)
    }
}
