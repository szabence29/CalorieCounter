import SwiftUI
import SwiftData

struct ManualAddView: View {
    @ObservedObject var viewModel: FoodViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedMeal: MealType = .breakfast
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChipsAndSearchBar
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.items.isEmpty && !viewModel.isLoading {
                            PlaceholderCard()
                                .padding(.top, 40)
                        } else {
                            ForEach(viewModel.items) { item in
                                NavigationLink {
                                    FoodDetailView(
                                        item: item,
                                        defaultMeal: selectedMeal,
                                        defaultDate: selectedDate
                                    ) { it, grams, meal, date in
                                        viewModel.addLogEntry(
                                            for: it,
                                            grams: grams,
                                            meal: meal,
                                            date: date,
                                            context: modelContext
                                        )
                                        dismiss()
                                    }
                                } label: {
                                    FoodCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    LoadingOverlay(title: "Searching…")
                }
            }
            .navigationTitle("Add foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Search") {
                            viewModel.fetchFoodsPaginated(query: searchText, pages: 1)
                        }
                        .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    //chips + kereső

    private var ChipsAndSearchBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MealType.allCases) { meal in
                        MealChip(
                            title: meal.rawValue,
                            isSelected: meal == selectedMeal
                        ) {
                            selectedMeal = meal
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                TextField(
                    "Search foods…",
                    text: $searchText,
                    onCommit: {
                        viewModel.fetchFoodsPaginated(query: searchText, pages: 1)
                    }
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.6 : 1)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        viewModel.items = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.6 : 1)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

//Reusable UI

private struct MealChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color(.systemGreen) : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct FoodCard: View {
    let item: APIFoodItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let url = item.imageUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.primaryName)
                    .font(.headline)
                    .lineLimit(1)

                let subtitle = item.servingLine.isEmpty
                    ? (item.brandOwner ?? "")
                    : item.servingLine

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(spacing: 2) {
                Text(item.energyKcal.map(String.init) ?? "—")
                    .font(.subheadline.weight(.semibold))
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 8)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.quaternaryLabel), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        )
    }
}

private struct PlaceholderCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Search foods to get started")
                .font(.headline)
            Text("Try typing e.g. “banana”, “oatmeal”, “yogurt”…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
    }
}

private struct LoadingOverlay: View {
    let title: String
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text(title)
                .font(.headline)
        }
        .padding(20)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(radius: 10)
        .accessibilityIdentifier("loadingOverlay")
    }
}
