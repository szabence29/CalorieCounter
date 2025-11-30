import SwiftUI
import SwiftData

struct FoodDetailLoaderSheet: View {
    let nlpItem: NLCommandResponse.Entities.Item
    let defaultMeal: MealType
    let defaultDate: Date

    @StateObject private var foodViewModel = FoodViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var itemName: String { nlpItem.name }

    private var defaultGramsFromNLP: Double? {
        if nlpItem.unit == "g", let q = nlpItem.quantity {
            return q
        }
        return nil
    }

    private var exactMatch: APIFoodItem? {
        let target = itemName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return foodViewModel.items.first { food in
            food.primaryName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == target
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let food = exactMatch {
                    FoodDetailView(
                        item: food,
                        defaultMeal: defaultMeal,
                        defaultDate: defaultDate,
                        defaultGrams: defaultGramsFromNLP
                    ) { item, grams, meal, date in
                        let entry = FoodLogEntry(
                            from: item,
                            grams: grams,
                            meal: meal,
                            date: date
                        )
                        modelContext.insert(entry)
                        dismiss()
                    }

                } else if foodViewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading \(itemName)…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    VStack(spacing: 8) {
                        Text("No exact match for “\(itemName)”")
                            .font(.body)
                        Text("Try changing the description or editing the item name.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(itemName.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if foodViewModel.items.isEmpty {
                foodViewModel.fetchFoods(query: itemName)
            }
        }
    }
}
