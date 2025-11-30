import SwiftUI

struct ParsedResultView: View {
    let originalText: String
    let response: NLCommandResponse

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                Text("Parsed command")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Original text")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    Text(highlightedText)
                        .font(.body)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected items")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    ForEach(response.entities.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name.capitalized)
                                    .font(.headline)

                                if let q = item.quantity,
                                   let unit = item.unit {
                                    Text("\(Int(q)) \(unit)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05),
                                        radius: 3, x: 0, y: 1)
                        )
                    }
                }

                if let meal = response.entities.meal {
                    Text("Meal: \(meal)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let date = response.entities.date {
                    Text("Date: \(date)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Result")
            .navigationBarTitleDisplayMode(.inline)
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
