import Foundation
import SwiftData

@Model
final class FoodItem {
    @Attribute(.unique) var fdcId: Int
    var foodDescription: String
    
    init(fdcId: Int, description: String) {
        self.fdcId = fdcId
        self.foodDescription = description
    }
}
