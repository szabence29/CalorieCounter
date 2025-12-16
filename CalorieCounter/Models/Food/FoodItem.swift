import Foundation
import SwiftData

// “Saved food” entitás: minimál perzisztencia (kedvencek / kiválasztott elemek).
@Model
final class FoodItem {
    @Attribute(.unique) var fdcId: Int
    var foodDescription: String

    init(fdcId: Int, description: String) {
        self.fdcId = fdcId
        self.foodDescription = description
    }
}
