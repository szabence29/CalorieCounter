import SwiftUI

// MARK: - Dashboard főnézet

struct DashboardView: View {
    // — Mintaadatok (később könnyen köthető profil/SwiftData adatokhoz)
    let goalCalories: Double = 2200
    let consumedCalories: Double = 200
    let carbsG: Double = 206
    let proteinG: Double = 35
    let fatG: Double = 32

    // csak az arányokhoz célok
    let targetCarbs: Double = 300
    let targetProtein: Double = 120
    let targetFat: Double = 80

    var progress: Double { min(consumedCalories / goalCalories, 1.0) }
    var remaining: Int { max(Int(goalCalories - consumedCalories), 0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Fejléc
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dashboard")
                        .font(.system(size: 32, weight: .bold))
                    Text(Date.now.formatted(.dateTime.weekday().month().day()))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Napi összegző kártya
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Daily Progress").font(.headline)
                            Spacer()
                            Text("\(Int((progress * 100).rounded())) %")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                        }

                        HalfRingProgress(progress: progress)
                            .frame(height: 180)
                            .overlay {
                                VStack(spacing: 6) {
                                    Text("\(remaining)")
                                        .font(.system(size: 44, weight: .bold))
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

                // Mai étkezések
                HStack {
                    Text("Today's Meals").font(.headline)
                    Spacer()
                    Button { } label: {
                        HStack(spacing: 4) {
                            Text("See all")
                            Image(systemName: "chevron.right").font(.caption)
                        }
                    }
                }

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

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
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
            // Háttér félkör (0..0.5 a kör fele)
            Circle()
                .trim(from: 0.0, to: 0.5)
                .rotation(.degrees(180))
                .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: thickness, lineCap: .butt))

            // Kitöltött rész
            Circle()
                .trim(from: 0.0, to: max(0.001, progress) * 0.5)
                .rotation(.degrees(180))
                .stroke(.primary, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        }
        .frame(height: 180)
        .padding(.horizontal, 24)
    }
}


#Preview {
    DashboardView()
}
