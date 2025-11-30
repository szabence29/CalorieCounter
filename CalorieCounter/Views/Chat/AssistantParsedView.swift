import SwiftUI

struct AssistantParsedView: View {
    let originalText: String
    let response: NLCommandResponse
    let onItemTap: (NLCommandResponse.Entities.Item, String?, String?) -> Void

    @State private var selectedItem: NLCommandResponse.Entities.Item?

    var body: some View {
       VStack(alignment: .leading, spacing: 6) {
           Text(highlightedText)
               .font(.body)

           if !response.entities.items.isEmpty {
               Divider().padding(.vertical, 4)

               ForEach(response.entities.items) { item in
                   Button {
                       onItemTap(item,
                                 response.entities.meal,
                                 response.entities.date)
                   } label: {
                       HStack {
                           Text(item.name.capitalized)
                               .font(.subheadline.bold())

                           Spacer()

                           if let q = item.quantity,
                              let unit = item.unit {
                               Text("\(Int(q)) \(unit)")
                                   .font(.caption)
                                   .foregroundStyle(.secondary)
                           }
                       }
                       .contentShape(Rectangle())
                   }
                   .buttonStyle(.plain)
               }
           }

           if let meal = response.entities.meal {
               Text("Meal: \(meal)")
                   .font(.caption)
                   .foregroundStyle(.secondary)
           }

           if let date = response.entities.date {
               Text("Date: \(date)")
                   .font(.caption)
                   .foregroundStyle(.secondary)
           }
       }
   }

    private var highlightedText: AttributedString {
        var attr = AttributedString(originalText)

        for item in response.entities.items {
            let target = item.name.lowercased()
            if let range = attr.range(
                of: target,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                attr[range].foregroundColor = .accentColor
                attr[range].font = .body.bold()
            }
        }

        return attr
    }
}
