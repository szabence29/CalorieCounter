import Foundation
import SwiftData

@Model
final class FoodLogEntry {
    var id: UUID
    var date: Date              // nap szerint (startOfDay)
    var mealRaw: String         // "Breakfast", "Lunch" stb.
    var grams: Double

    // egyszerűsített „snapshot” az ételről
    var name: String
    var energyKcal: Int
    var carbs_g: Double?
    var protein_g: Double?
    var fat_g: Double?

    init(from item: APIFoodItem,
         grams: Double,
         meal: MealType,
         date: Date)
    {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.mealRaw = meal.rawValue
        self.grams = grams

        self.name = item.primaryName

        let base = item.servingSize ?? 100
        let factor = base > 0 ? grams / base : grams / 100

        self.energyKcal = Int(
            (Double(item.energyKcal ?? 0) * factor).rounded()
        )
        self.carbs_g = item.carbohydrates_total_g.map { $0 * factor }
        self.protein_g = item.protein_g.map { $0 * factor }
        self.fat_g = item.fat_total_g.map { $0 * factor }
    }

    var meal: MealType {
        get { MealType(rawValue: mealRaw) ?? .breakfast }
        set { mealRaw = newValue.rawValue }
    }
}
