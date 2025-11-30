import Foundation

enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snack     = "Snack"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }
}

extension MealType {
    init(fromNLString value: String?) {
        let lower = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch lower {
        case "breakfast": self = .breakfast
        case "lunch":     self = .lunch
        case "dinner":    self = .dinner
        case "snack":     self = .snack
        default:          self = .breakfast
        }
    }
}
