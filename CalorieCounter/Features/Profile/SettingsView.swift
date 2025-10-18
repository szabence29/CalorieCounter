import SwiftUI

// MARK: - Shared models

// Felhasználói választásokhoz használt enumok.
// RawValue-ként tárolhatók @AppStorage-ban, majd visszaalakíthatók.
enum WeightUnit: String, CaseIterable, Identifiable { case kg, lbs; var id: String { rawValue } }
enum HeightUnit: String, CaseIterable, Identifiable { case cm, ftIn; var id: String { rawValue } }
enum Sex: String, CaseIterable, Identifiable { case male, female; var id: String { rawValue } }

enum Goal: String, CaseIterable, Identifiable {
    // Fő cél: fogyni / szinten tartani / izmot építeni
    case lose = "Lose weight", maintain = "Maintain", gain = "Gain muscle"
    var id: String { rawValue }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    // Aktivitási szintek az alap TDEE számításhoz
    case sedentary = "Sedentary", light = "Lightly active", moderate = "Moderately active",
         very = "Very active", athlete = "Athlete"
    var id: String { rawValue }
    // A TDEE faktor, amivel BMR-t szorozzuk
    var factor: Double {
        switch self {
            case .sedentary: 1.2
            case .light: 1.375
            case .moderate: 1.55
            case .very: 1.725
            case .athlete: 1.9
        }
    }
}

// MARK: - Shared conversions

// Egységkonverziók
func kgToLbs(_ kg: Double) -> Double { kg * 2.2046226218 }
func lbsToKg(_ lbs: Double) -> Double { lbs / 2.2046226218 }

func cmToFeetInches(_ cm: Double) -> (Int, Double) {
    // cm → inch → szétbontás lábra és maradék inch-re
    let totalInches = cm / 2.54
    let feet = Int(totalInches / 12.0)
    let inches = totalInches - Double(feet) * 12.0
    return (feet, inches)
}
func feetInchesToCm(feet: Int, inches: Double) -> Double {
    // láb+inch → össz-inchek → cm
    (Double(feet) * 12.0 + inches) * 2.54
}

// Alapanyagcsere (BMR) – Mifflin–St Jeor képlet
func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
    switch sex {
    case .male:   return 10*weightKg + 6.25*heightCm - 5*Double(age) + 5
    case .female: return 10*weightKg + 6.25*heightCm - 5*Double(age) - 161
    }
}

// Napi energiafelhasználás (TDEE) aktivitási faktorral
func tdee(bmr: Double, activity: ActivityLevel) -> Double { bmr * activity.factor }

// Cél szerinti kalóriakorrekció (heti tömegdelta → napi kcal)
// 1 kg ~ 7700 kcal; napi eltolás = (hetiDeltaKg * 7700) / 7
func adjustedCalories(tdee: Double, weeklyDeltaKg: Double) -> Double {
    tdee + (weeklyDeltaKg * 7700.0) / 7.0
}

// MARK: - SettingsView

struct SettingsView: View {
    // ── Perzisztens beállítások (UserDefaults) @AppStorage kulcsokkal ─────────
    @AppStorage("name") private var name: String = "Gipsz Jakab"
    @AppStorage("age") private var age: Int = 28
    @AppStorage("sex") private var sexRaw: String = Sex.male.rawValue

    @AppStorage("weightKg") private var weightKg: Double = 80
    @AppStorage("heightCm") private var heightCm: Double = 178
    @AppStorage("startingWeightKg") private var startingWeightKg: Double = 84
    @AppStorage("goalWeightKg") private var goalWeightKg: Double = 75

    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("heightUnit") private var heightUnitRaw: String = HeightUnit.cm.rawValue

    @AppStorage("activity") private var activityRaw: String = ActivityLevel.moderate.rawValue
    @AppStorage("goal") private var goalRaw: String = Goal.maintain.rawValue
    @AppStorage("weeklyDeltaKg") private var weeklyDeltaKg: Double = -0.25 // negatív: fogyás

    // ── Származtatott olvasók: RawValue → típus ───────────────────────────────
    private var sex: Sex { Sex(rawValue: sexRaw) ?? .male }
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    private var heightUnit: HeightUnit { HeightUnit(rawValue: heightUnitRaw) ?? .cm }
    private var activity: ActivityLevel { ActivityLevel(rawValue: activityRaw) ?? .moderate }
    private var goal: Goal { Goal(rawValue: goalRaw) ?? .maintain }

    // ── UI state a ft+inch szerkesztéséhez (cm ↔ ft+in kétirányú) ────────────
    @State private var feet: Int = 5
    @State private var inches: Double = 10

    // Számformázó decimális beviteli mezőkhöz
    private let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 0
        return nf
    }()

    var body: some View {
        ZStack {
            // Rendszeres grouped háttér
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {

                    // Cím
                    HStack {
                        Text("Settings").font(.system(size: 28, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal)

                    // ── PROFILE kártya ──────────────────────────────────────────
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Profile").font(.headline)

                            VStack(spacing: 12) {
                                // Név mező
                                LabeledTextField(title: "Name", text: $name)

                                // Életkor – számmező + stepper + tartomány klampelés
                                IntEditorRow(title: "Age", value: $age, range: 10...100)

                                // Nem – generikus PickerRow enumhoz
                                PickerRow(
                                    title: "Sex",
                                    selection: Binding<Sex>(
                                        get: { sex },
                                        set: { sexRaw = $0.rawValue } // @AppStorage raw mentés
                                    ),
                                    options: Sex.allCases,
                                    label: { $0.rawValue.capitalized }
                                )
                            }
                        }
                    }

                    // ── UNITS kártya (mértékegységek) ──────────────────────────
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Units").font(.headline)

                            PickerRow(
                                title: "Weight Unit",
                                selection: Binding<WeightUnit>(
                                    get: { weightUnit },
                                    set: { weightUnitRaw = $0.rawValue }
                                ),
                                options: WeightUnit.allCases,
                                label: { $0.rawValue.uppercased() }
                            )

                            PickerRow(
                                title: "Height Unit",
                                selection: Binding<HeightUnit>(
                                    get: { heightUnit },
                                    set: { heightUnitRaw = $0.rawValue }
                                ),
                                options: HeightUnit.allCases,
                                label: { $0 == .cm ? "cm" : "ft + in" }
                            )
                        }
                    }

                    // ── BODY METRICS kártya ────────────────────────────────────
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Body Metrics").font(.headline)

                            // Aktuális súly – egységfüggő kétirányú binding
                            if weightUnit == .kg {
                                NumericField(title: "Weight (kg)", value: $weightKg, formatter: numberFormatter)
                            } else {
                                NumericField(
                                    title: "Weight (lbs)",
                                    value: Binding(
                                        get: { kgToLbs(weightKg) },
                                        set: { weightKg = lbsToKg($0) } // visszaírjuk kg-ban
                                    ),
                                    formatter: numberFormatter
                                )
                            }

                            // Kezdő / Cél súly – szintén egységfüggő
                            if weightUnit == .kg {
                                NumericField(title: "Starting weight (kg)", value: $startingWeightKg, formatter: numberFormatter)
                                NumericField(title: "Goal weight (kg)", value: $goalWeightKg, formatter: numberFormatter)
                            } else {
                                NumericField(
                                    title: "Starting weight (lbs)",
                                    value: Binding(
                                        get: { kgToLbs(startingWeightKg) },
                                        set: { startingWeightKg = lbsToKg($0) }
                                    ),
                                    formatter: numberFormatter
                                )
                                NumericField(
                                    title: "Goal weight (lbs)",
                                    value: Binding(
                                        get: { kgToLbs(goalWeightKg) },
                                        set: { goalWeightKg = lbsToKg($0) }
                                    ),
                                    formatter: numberFormatter
                                )
                            }

                            // Magasság – cm vagy ft+in szerkesztés
                            if heightUnit == .cm {
                                NumericField(title: "Height (cm)", value: $heightCm, formatter: numberFormatter)
                            } else {
                                // Ha ft+in van kiválasztva, a cm értéket bontjuk szét,
                                // és két mezővel szerkeszthető; visszaírjuk cm-be.
                                let ftIn = cmToFeetInches(heightCm)
                                HStack(spacing: 12) {
                                    IntEditorRowInline(
                                        title: "ft",
                                        value: Binding(
                                            get: { feet == 0 ? ftIn.0 : feet },
                                            set: {
                                                feet = $0
                                                heightCm = feetInchesToCm(feet: feet, inches: inches)
                                            }
                                        ),
                                        range: 3...8,
                                        width: 56
                                    )

                                    NumericField(
                                        title: "in",
                                        value: Binding(
                                            get: { inches == 0 ? ftIn.1 : inches },
                                            set: {
                                                // inch értéket 0...11.99 közé fogjuk
                                                inches = max(0, min(11.99, $0))
                                                heightCm = feetInchesToCm(feet: feet, inches: inches)
                                            }
                                        ),
                                        formatter: numberFormatter
                                    )
                                }
                                // Első megjelenéskor szinkronizáljuk a lokális state-et
                                .onAppear {
                                    feet = ftIn.0
                                    inches = ftIn.1
                                }
                            }
                        }
                    }

                    // ── GOALS kártya ───────────────────────────────────────────
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Goals").font(.headline)

                            PickerRow(
                                title: "Primary Goal",
                                selection: Binding<Goal>(
                                    get: { goal },
                                    set: { goalRaw = $0.rawValue }
                                ),
                                options: Goal.allCases,
                                label: { $0.rawValue }
                            )

                            PickerRow(
                                title: "Activity",
                                selection: Binding<ActivityLevel>(
                                    get: { activity },
                                    set: { activityRaw = $0.rawValue }
                                ),
                                options: ActivityLevel.allCases,
                                label: { $0.rawValue }
                            )

                            // Heti tömegdelta kg/hét-ben; ez alapján módosítjuk a napi kalóriát
                            VStack(alignment: .leading, spacing: 8) {
                                let label: String = {
                                    switch goal {
                                    case .lose:     return "Weekly loss (kg/wk)"
                                    case .maintain: return "Adjustment (kg/wk)"
                                    case .gain:     return "Weekly gain (kg/wk)"
                                    }
                                }()
                                NumericField(title: label, value: $weeklyDeltaKg, formatter: numberFormatter)

                                Text("Tipikus: −0.25…−0.75 kg/hét (fogyás) · +0.1…+0.25 kg/hét (izom).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // ── CALORIES PREVIEW kártya ────────────────────────────────
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calories (estimates)").font(.headline)

                            // BMR → TDEE → cél szerinti napi kalória
                            let b = bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
                            let t = tdee(bmr: b, activity: activity)
                            let target = adjustedCalories(tdee: t, weeklyDeltaKg: weeklyDeltaKg)

                            StatRow(title: "BMR", value: "\(Int(round(b))) kcal")
                            StatRow(title: "TDEE", value: "\(Int(round(t))) kcal")
                            Divider().padding(.vertical, 4)
                            StatRow(title: "Suggested daily calories", value: "\(Int(round(target))) kcal")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }

                    // Mentésről visszajelzés
                    Text("All changes are saved automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)
                        .padding(.top, 4)
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - Reusable UI

// Fehér „kártya” konténer, árnyékkal és lekerekítéssel
private struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content().padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
        .padding(.horizontal)
    }
}

// Címkézett sima szövegmező (névhez)
private struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// Címkézett számmező Double-hoz (formatterrel)
private struct NumericField: View {
    let title: String
    @Binding var value: Double
    let formatter: NumberFormatter
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            TextField(title, value: $value, formatter: formatter)
                .keyboardType(.decimalPad)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// Int editor: cím + beírható szám + stepper, biztonságos tartomány-klampeléssel
private struct IntEditorRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()

            // Csak számjegyeket engedünk; klampelve a range-be
            TextField("", text: Binding(
                get: { String(value) },
                set: { new in
                    let filtered = new.filter { $0.isNumber }
                    if let v = Int(filtered) {
                        value = min(max(v, range.lowerBound), range.upperBound)
                    }
                })
            )
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 56)
            .padding(8)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Stepper("", value: $value, in: range).labelsHidden()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Kompakt Int editor (ft mezőhöz), kisebb paddinggel és szélességmegadással
private struct IntEditorRowInline: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 56

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)

            TextField("", text: Binding(
                get: { String(value) },
                set: { new in
                    let filtered = new.filter { $0.isNumber }
                    if let v = Int(filtered) {
                        value = min(max(v, range.lowerBound), range.upperBound)
                    }
                })
            )
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: width)
            .padding(8)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Stepper("", value: $value, in: range).labelsHidden()
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// Egyszerű cím–érték sor (jobb oldalra húzott értékkel)
private struct StatRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

// Generikus Picker sor: bármely Identifiable & Hashable típus listázásához.
// A kiválasztás @Bindinggel történik, a megjelenített szöveget a `label` closure adja.
private struct PickerRow<T: Identifiable & Hashable>: View {
    let title: String
    @Binding var selection: T
    var options: [T]
    var label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)

            Menu {
                ForEach(options, id: \.id) { opt in
                    Button(label(opt)) { selection = opt }
                }
            } label: {
                HStack {
                    Text(label(selection)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

// Xcode preview a SettingsView-hoz
#Preview { SettingsView() }
