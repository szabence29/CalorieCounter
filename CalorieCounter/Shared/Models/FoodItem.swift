import Foundation

struct FoodItem: Identifiable, Decodable {
    let fdcId: Int
    let description: String
    var id: Int { fdcId }
}
