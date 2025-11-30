import SwiftUI
import SwiftData

// MARK: - Date helpers

extension Date {
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    func stripped() -> Date { Calendar.current.startOfDay(for: self) }
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var displayTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMM d, EEEE")
        return f.string(from: self)
    }
    var shortMealsHeader: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f.string(from: self)
    }
}

// MARK: - Date pager

struct DatePager: View {
    let date: Date
    let onPrev: () -> Void
    let onNext: () -> Void
    let onPick: (Date) -> Void

    @State private var showPicker = false
    @State private var pickerDate: Date = .now

    var body: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPrev()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }

            Button {
                pickerDate = date
                showPicker = true
            } label: {
                Text(date.displayTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
            .sheet(isPresented: $showPicker) {
                VStack {
                    DatePicker(
                        "Pick a day",
                        selection: $pickerDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Button("Use this day") {
                        onPick(pickerDate)
                        showPicker = false
                    }
                    .padding(.bottom, 12)
                }
                .presentationDetents([.medium, .large])
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
            }
        }
    }
}

// MARK: - Dashboard főnézet

struct DashboardView: View {
    // SwiftData
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodLogEntry.date, order: .forward)
    private var allLogs: [FoodLogEntry]

    @State private var selectedDate: Date = Date().stripped()
    enum SwipeDir { case left, right }
    @State private var lastSwipe: SwipeDir = .left

    // kalóriacél – egyelőre fix, később jöhet UserProfile-ból
    let goalCalories: Double = 2200

    private let swipeThreshold: CGFloat = 60

    // MARK: - Napi aggregált adatok (SwiftData-ból)

    var logsForSelectedDay: [FoodLogEntry] {
        allLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var consumedCalories: Double {
        logsForSelectedDay.reduce(0) { $0 + Double($1.energyKcal) }
    }

    var carbsG: Double {
        logsForSelectedDay.reduce(0) { $0 + ($1.carbs_g ?? 0) }
    }

    var proteinG: Double {
        logsForSelectedDay.reduce(0) { $0 + ($1.protein_g ?? 0) }
    }

    var fatG: Double {
        logsForSelectedDay.reduce(0) { $0 + ($1.fat_g ?? 0) }
    }

    var progress: Double {
        goalCalories > 0 ? min(consumedCalories / goalCalories, 1.0) : 0
    }

    var remaining: Int {
        max(Int(goalCalories - consumedCalories), 0)
    }


    func logs(for meal: MealType) -> [FoodLogEntry] {
        logsForSelectedDay.filter { $0.meal == meal }
    }

    func totalCalories(for meal: MealType) -> Int {
        logs(for: meal).reduce(0) { $0 + $1.energyKcal }
    }

    func mealItems(for meal: MealType) -> [MealItem] {
        logs(for: meal).map { entry in
            MealItem(name: entry.name, cals: entry.energyKcal)
        }
    }

    private func step(days: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            if days > 0 { lastSwipe = .left } else { lastSwipe = .right }
            selectedDate = selectedDate.adding(days: days)
        }
    }

    private func pick(_ newDate: Date) {
        let new = newDate.stripped()
        guard new != selectedDate else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            lastSwipe = (new > selectedDate) ? .left : .right
            selectedDate = new
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Dashboard")
                        .font(.system(size: 32, weight: .bold))

                    DatePager(
                        date: selectedDate,
                        onPrev: { step(days: -1) },
                        onNext: { step(days: +1) },
                        onPick: { pick($0) }
                    )
                }
                .padding(.top, 8)

                Group {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Daily Progress")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int((progress * 100).rounded())) %")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .contentTransition(.numericText())
                            }

                            HalfRingProgress(progress: progress)
                                .frame(height: 180)
                                .overlay {
                                    VStack(spacing: 6) {
                                        Text("\(remaining)")
                                            .font(.system(size: 44, weight: .bold))
                                            .contentTransition(.numericText())
                                        Text("calories remaining")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                    }
                                    .offset(y: 10)
                                }

                            Text(progress < 1 ? "Keep up the good work!" : "Goal reached 🎉")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .center)

                            HStack(spacing: 16) {
                                MiniStat(
                                    title: "Consumed",
                                    value: "\(Int(consumedCalories.rounded()))"
                                )
                                MiniStat(
                                    title: "Goal",
                                    value: "\(Int(goalCalories))"
                                )
                            }

                            VStack(spacing: 14) {
                                MacroBar(
                                    label: "Carbs",
                                    value: carbsG,
                                    target: 300
                                )
                                MacroBar(
                                    label: "Protein",
                                    value: proteinG,
                                    target: 120
                                )
                                MacroBar(
                                    label: "Fat",
                                    value: fatG,
                                    target: 80
                                )
                            }
                            .padding(.top, 4)
                        }
                    }

                    HStack {
                        Text(selectedDate.isToday
                             ? "Today's Meals"
                             : "\(selectedDate.shortMealsHeader) • Meals"
                        )
                        .font(.headline)
                        Spacer()
                    }

                    if logsForSelectedDay.isEmpty {
                        Text("No meals logged for this day yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        // Breakfast
                        if !logs(for: .breakfast).isEmpty {
                            SurfaceCard {
                                MealRow(
                                    title: "Breakfast",
                                    time: selectedDate.isToday ? "Today" : "",
                                    totalCals: totalCalories(for: .breakfast),
                                    items: mealItems(for: .breakfast)
                                )
                            }
                        }

                        // Lunch
                        if !logs(for: .lunch).isEmpty {
                            SurfaceCard {
                                MealRow(
                                    title: "Lunch",
                                    time: selectedDate.isToday ? "Today" : "",
                                    totalCals: totalCalories(for: .lunch),
                                    items: mealItems(for: .lunch)
                                )
                            }
                        }

                        // Dinner
                        if !logs(for: .dinner).isEmpty {
                            SurfaceCard {
                                MealRow(
                                    title: "Dinner",
                                    time: selectedDate.isToday ? "Today" : "",
                                    totalCals: totalCalories(for: .dinner),
                                    items: mealItems(for: .dinner)
                                )
                            }
                        }

                        // Snack
                        if !logs(for: .snack).isEmpty {
                            SurfaceCard {
                                MealRow(
                                    title: "Snack",
                                    time: selectedDate.isToday ? "Today" : "",
                                    totalCals: totalCalories(for: .snack),
                                    items: mealItems(for: .snack)
                                )
                            }
                        }
                    }
                }
                .id(selectedDate)
                .transition(.asymmetric(
                    insertion: .move(edge: lastSwipe == .left ? .trailing : .leading)
                        .combined(with: .opacity),
                    removal: .move(edge: lastSwipe == .left ? .leading  : .trailing)
                        .combined(with: .opacity)
                ))
                .animation(.spring(response: 0.45, dampingFraction: 0.9), value: selectedDate)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy), abs(dx) > swipeThreshold else { return }
                    if dx < 0 { step(days: +1) } else { step(days: -1) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        )
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - UI komponensek

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading) { content() }
            .padding(16)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

struct MiniStat: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double

    var ratio: Double { min(value / max(target, 1), 1) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text("\(Int(value.rounded()))g")
                    .font(.caption.weight(.semibold))
            }
            ZstackBar(ratio: ratio)
                .frame(height: 6)
        }
    }

    @ViewBuilder
    private func ZstackBar(ratio: Double) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color(.tertiarySystemFill))
            GeometryReader { geo in
                Capsule()
                    .fill(.tint)
                    .frame(width: max(8, geo.size.width * ratio))
            }
        }
    }
}

struct MealItem { let name: String; let cals: Int }

struct MealRow: View {
    let title: String
    let time: String
    let totalCals: Int
    let items: [MealItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(totalCals) cal").font(.headline)
            }
            if !time.isEmpty {
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !items.isEmpty {
                Divider().padding(.vertical, 4)
                ForEach(items.indices, id: \.self) { i in
                    HStack {
                        Text(items[i].name)
                        Spacer()
                        Text("\(items[i].cals) cal")
                            .foregroundStyle(.secondary)
                    }
                    if i != items.indices.last {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
    }
}

// MARK: - Félkör progressz

struct HalfRingProgress: View {
    var progress: Double        // 0...1
    var thickness: CGFloat = 8  // vonalvastagság

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.0, to: 0.5)
                .rotation(.degrees(180))
                .stroke(
                    Color(.systemGray4),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .butt)
                )

            Circle()
                .trim(from: 0.0, to: max(0.001, progress) * 0.5)
                .rotation(.degrees(180))
                .stroke(
                    .primary,
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
        }
        .frame(height: 180)
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .preferredColorScheme(.light)
}
