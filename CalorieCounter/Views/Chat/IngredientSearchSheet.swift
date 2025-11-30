import SwiftUI

struct IngredientSearchSheet: View {
    let itemName: String

    @StateObject private var foodViewModel = FoodViewModel()
    @Environment(\.dismiss) private var dismiss

    private var filteredItems: [APIFoodItem] {
        let target = itemName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return foodViewModel.items.filter { food in
            let name = food.primaryName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return name == target
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if foodViewModel.isLoading && foodViewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching for \(itemName)…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Text("No matching items found.")
                            .font(.body)
                        Text("Try a different description or check your internet connection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredItems) { food in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.primaryName)
                                    .font(.body)

                                let serving = food.servingLine
                                if !serving.isEmpty {
                                    Text(serving)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let kcal = food.energyKcal {
                                Text("\(kcal) kcal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
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
