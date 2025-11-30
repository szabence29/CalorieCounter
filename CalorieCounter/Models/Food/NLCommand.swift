import Foundation

struct NLCommandResponse: Codable {
    struct Entities: Codable {
        struct Item: Codable, Identifiable, Hashable {
            let id = UUID()
            let name: String
            let quantity: Double?
            let unit: String?
        }

        let items: [Item]
        let meal: String?
        let date: String?
    }

    let intent: String
    let entities: Entities
    let missing_fields: [String]
}

