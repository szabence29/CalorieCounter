import Foundation
import Combine

struct FoodResponse: Decodable {
    let foods: [FoodItem]
    let totalHits: Int
}

class FoodViewModel: ObservableObject {
    @Published var items: [FoodItem] = []
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
            .map { $0.foods } // Remove the filter to show all foods
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: &$items)
    }
}
