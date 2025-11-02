import Foundation

struct FoodGroup: Identifiable {
    let id = UUID()
    let name: String
    let items: [APIFoodItem]

    var representative: APIFoodItem? { items.first }
    var count: Int { items.count }

    var kcalRangeText: String {
        let kcals = items.compactMap { $0.energyKcal }
        guard let min = kcals.min(), let max = kcals.max() else { return "— cal" }
        return (min == max) ? "\(min) cal" : "\(min)–\(max) cal"
    }

    var servingSample: String {
        if let r = representative, !r.servingLine.isEmpty { return r.servingLine }
        return items.first?.servingLine ?? ""
    }
}
