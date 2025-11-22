import SwiftUI

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

// MARK: - Date pager (nyilak + tappolható dátum + sheet picker)
// Nem módosít közvetlenül dátumot; a szülőnek jelez (onPrev/onNext/onPick)

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
    // — Mintaadatok (később köthető profil/SwiftData adatokhoz)
    let goalCalories: Double = 2200
    let consumedCalories: Double = 200
    let carbsG: Double = 206
    let proteinG: Double = 35
    let fatG: Double = 32

    // csak az arányokhoz célok
    let targetCarbs: Double = 300
    let targetProtein: Double = 120
    let targetFat: Double = 80

    // kiválasztott nap + animáció iránya
    @State private var selectedDate: Date = Date().stripped()
    enum SwipeDir { case left, right } // left = előre (jövő), right = vissza (múlt)
    @State private var lastSwipe: SwipeDir = .left

    var progress: Double { min(consumedCalories / goalCalories, 1.0) }
    var remaining: Int { max(Int(goalCalories - consumedCalories), 0) }

    private let swipeThreshold: CGFloat = 60

    // Központosított léptetés – itt állítjuk az irányt és a dátumot is
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

                // Fejléc + dátumnavigátor
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

                // ===== NAPI TARTALOM – aszimmetrikus be/kiúszás irány szerint =====
                Group {
                    // Napi összegző kártya
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Daily Progress").font(.headline)
                                Spacer()
                                Text("\(Int((progress * 100).rounded())) %")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .contentTransition(.numericText()) // iOS 17+
                            }

                            HalfRingProgress(progress: progress)
                                .frame(height: 180)
                                .overlay {
                                    VStack(spacing: 6) {
                                        Text("\(remaining)")
                                            .font(.system(size: 44, weight: .bold))
                                            .contentTransition(.numericText()) // iOS 17+
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
                                MiniStat(title: "Consumed", value: "\(Int(consumedCalories))")
                                MiniStat(title: "Goal", value: "\(Int(goalCalories))")
                            }

                            VStack(spacing: 14) {
                                MacroBar(label: "Carbs", value: carbsG, target: targetCarbs)
                                MacroBar(label: "Protein", value: proteinG, target: targetProtein)
                                MacroBar(label: "Fat", value: fatG, target: targetFat)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // Napi étkezések fejléc
                    HStack {
                        Text(selectedDate.isToday ? "Today's Meals" : "\(selectedDate.shortMealsHeader) • Meals")
                            .font(.headline)
                        Spacer()
                        Button { /* See all for selectedDate */ } label: {
                            HStack(spacing: 4) {
                                Text("See all")
                                Image(systemName: "chevron.right").font(.caption)
                            }
                        }
                    }

                    // Példa kártyák (a selectedDate-hez köthető lekéréseknek itt a helye)
                    SurfaceCard {
                        MealRow(
                            title: "Breakfast",
                            time: "8:30 AM",
                            totalCals: 420,
                            items: [
                                .init(name: "Oatmeal with berries", cals: 320),
                                .init(name: "Black coffee", cals: 5),
                                .init(name: "Greek yogurt", cals: 95),
                            ]
                        )
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Lunch").font(.headline)
                                Spacer()
                                Text("650 cal").font(.headline)
                            }
                            Text("Chicken bowl, rice, salad")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                // az egész “nap tartalma” egyazon azonosítóval
                .id(selectedDate)
                .transition(.asymmetric(
                    insertion: .move(edge: lastSwipe == .left ? .trailing : .leading).combined(with: .opacity),
                    removal:   .move(edge: lastSwipe == .left ? .leading  : .trailing).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.45, dampingFraction: 0.9), value: selectedDate)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        // Swipe – csak vízszintes gesztusra léptetünk (nem akad a scrollba)
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
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.bold))
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
                Text("\(Int(value))g").font(.caption.weight(.semibold))
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
            Text(time).font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, 4)
            ForEach(items.indices, id: \.self) { i in
                HStack {
                    Text(items[i].name)
                    Spacer()
                    Text("\(items[i].cals) cal").foregroundStyle(.secondary)
                }
                if i != items.indices.last { Divider().opacity(0.4) }
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
                .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: thickness, lineCap: .butt))

            Circle()
                .trim(from: 0.0, to: max(0.001, progress) * 0.5)
                .rotation(.degrees(180))
                .stroke(.primary, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
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
