import SwiftUI

private let ACTION_HEIGHT: CGFloat = 56

struct FoodDetailView: View {
    let item: APIFoodItem
    let defaultMeal: MealType
    let defaultDate: Date
    let onAdd: (_ item: APIFoodItem, _ grams: Double, _ meal: MealType, _ date: Date) -> Void

    @State private var grams: Double
    @State private var meal: MealType
    @State private var date: Date
    @State private var showPicker = false

    init(
        item: APIFoodItem,
        defaultMeal: MealType,
        defaultDate: Date,
        defaultGrams: Double? = nil,
        onAdd: @escaping (_ item: APIFoodItem, _ grams: Double, _ meal: MealType, _ date: Date) -> Void
    ) {
        self.item = item
        self.defaultMeal = defaultMeal
        self.defaultDate = defaultDate
        self.onAdd = onAdd

        let base = item.servingSize ?? 100
        let startGrams = defaultGrams ?? base

        _grams = State(initialValue: startGrams)
        _meal  = State(initialValue: defaultMeal)
        _date  = State(initialValue: Calendar.current.startOfDay(for: defaultDate))
    }

    // Skálázási faktor a megadott gramhoz
    private var factor: Double {
        let base = item.servingSize ?? 100
        return base > 0 ? grams / base : grams / 100
    }

    private var scaledKcal: Int?      { item.energyKcal.map { Int(round(Double($0) * factor)) } }
    private var scaledProtein: Double?{ item.protein_g.map { $0 * factor } }
    private var scaledFat: Double?    { item.fat_total_g.map { $0 * factor } }
    private var scaledCarbs: Double?  { item.carbohydrates_total_g.map { $0 * factor } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Fejléc képkártya – scaledToFit: minden sarok látszik
                HeaderImage(url: item.imageUrl)
                    .frame(height: 260)
                    .padding(.top, 4)

                Text(item.primaryName)
                    .font(.title2.weight(.bold))

                if !item.servingLine.isEmpty {
                    Text(item.servingLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Gramm beállítás
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(Int(grams)) g")
                                .monospacedDigit()
                            Stepper("", value: $grams, in: 1...1500, step: 5)
                                .labelsHidden()
                        }
                    }
                    Slider(value: $grams, in: 1...1500, step: 1)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Skálázott értékek
                HStack(spacing: 12) {
                    StatBox(
                        title: "Calories",
                        value: scaledKcal.map { "\($0) kcal" } ?? "—"
                    )
                    StatBox(
                        title: "Protein",
                        value: scaledProtein.map { String(format: "%.1f g", $0) } ?? "—"
                    )
                    StatBox(
                        title: "Carbs",
                        value: scaledCarbs.map { String(format: "%.1f g", $0) } ?? "—"
                    )
                    StatBox(
                        title: "Fat",
                        value: scaledFat.map { String(format: "%.1f g", $0) } ?? "—"
                    )
                }

                // Étkezés + dátum
                HStack(spacing: 12) {
                    Menu {
                        ForEach(MealType.allCases) { m in
                            Button(m.rawValue) { meal = m }
                        }
                    } label: {
                        Label(meal.rawValue, systemImage: "fork.knife")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label(
                            date.formatted(.dateTime.year().month().day()),
                            systemImage: "calendar"
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .sheet(isPresented: $showPicker) {
                        VStack {
                            DatePicker(
                                "Date",
                                selection: $date,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .padding()

                            Button("Done") {
                                showPicker = false
                            }
                            .padding(.bottom, 12)
                        }
                        .presentationDetents([.medium, .large])
                    }

                    Spacer()
                }

                Spacer(minLength: 8)
            }
            .padding(16)
            .padding(.bottom, ACTION_HEIGHT + 24)
        }
        .navigationTitle("Food details")
        .navigationBarTitleDisplayMode(.inline)
        // Fix alsó gomb – mindig a tabbar fölött ül
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    onAdd(item, grams, meal, date)
                } label: {
                    Text("Add to \(meal.rawValue)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: ACTION_HEIGHT)
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }
    }
}

// Képkártya komponens – biztosítja, hogy a kép ne legyen kivágva
private struct HeaderImage: View {
    let url: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFit()
                            .padding(8)
                    case .empty:
                        ProgressView()
                    default:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .opacity(0.3)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
