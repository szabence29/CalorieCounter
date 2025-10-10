import SwiftUI

// MARK: - Shared models (define ONCE in the module)

enum WeightUnit: String, CaseIterable, Identifiable { case kg, lbs; var id: String { rawValue } }
enum HeightUnit: String, CaseIterable, Identifiable { case cm, ftIn; var id: String { rawValue } }
enum Sex: String, CaseIterable, Identifiable { case male, female; var id: String { rawValue } }
enum Goal: String, CaseIterable, Identifiable {
    case lose = "Lose weight", maintain = "Maintain", gain = "Gain muscle"
    var id: String { rawValue }
}
enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary = "Sedentary", light = "Lightly active", moderate = "Moderately active",
         very = "Very active", athlete = "Athlete"
    var id: String { rawValue }
    var factor: Double {
        switch self {
            case .sedentary: 1.2;
            case .light: 1.375;
            case .moderate: 1.55;
            case .very: 1.725;
            case .athlete: 1.9
        }
    }
}

// MARK: - Shared conversions & calorie math (define ONCE)

func kgToLbs(_ kg: Double) -> Double { kg * 2.2046226218 }
func lbsToKg(_ lbs: Double) -> Double { lbs / 2.2046226218 }
func cmToFeetInches(_ cm: Double) -> (Int, Double) {
    let totalInches = cm / 2.54
    let feet = Int(totalInches / 12.0)
    let inches = totalInches - Double(feet) * 12.0
    return (feet, inches)
}
func feetInchesToCm(feet: Int, inches: Double) -> Double { (Double(feet) * 12.0 + inches) * 2.54 }

func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
    switch sex { case .male: return 10*weightKg + 6.25*heightCm - 5*Double(age) + 5
                 case .female: return 10*weightKg + 6.25*heightCm - 5*Double(age) - 161 }
}
func tdee(bmr: Double, activity: ActivityLevel) -> Double { bmr * activity.factor }
func adjustedCalories(tdee: Double, weeklyDeltaKg: Double) -> Double { tdee + (weeklyDeltaKg * 7700.0) / 7.0 }

// MARK: - SettingsView

struct SettingsView: View {
    // AppStorage – megosztott és perzisztens
    @AppStorage("name") private var name: String = "Alex Johnson"
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
    @AppStorage("weeklyDeltaKg") private var weeklyDeltaKg: Double = -0.25

    // Derived (olvasáshoz)
    private var sex: Sex { Sex(rawValue: sexRaw) ?? .male }
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    private var heightUnit: HeightUnit { HeightUnit(rawValue: heightUnitRaw) ?? .cm }
    private var activity: ActivityLevel { ActivityLevel(rawValue: activityRaw) ?? .moderate }
    private var goal: Goal { Goal(rawValue: goalRaw) ?? .maintain }

    // UI state (ft+in)
    @State private var feet: Int = 5
    @State private var inches: Double = 10

    private let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = 0
        return nf
    }()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {

                    // Title
                    HStack { Text("Settings").font(.system(size: 28, weight: .bold)); Spacer() }
                        .padding(.horizontal)

                    // PROFILE
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Profile").font(.headline)
                            VStack(spacing: 12) {
                                LabeledTextField(title: "Name", text: $name)

                                // ÚJ: IntEditorRow – érték látszik + írható + stepper
                                IntEditorRow(title: "Age", value: $age, range: 10...100)

                                PickerRow(
                                    title: "Sex",
                                    selection: Binding<Sex>(get: { sex }, set: { sexRaw = $0.rawValue }),
                                    options: Sex.allCases,
                                    label: { $0.rawValue.capitalized }
                                )
                            }
                        }
                    }

                    // UNITS
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Units").font(.headline)

                            PickerRow(
                                title: "Weight Unit",
                                selection: Binding<WeightUnit>(get: { weightUnit }, set: { weightUnitRaw = $0.rawValue }),
                                options: WeightUnit.allCases,
                                label: { $0.rawValue.uppercased() }
                            )

                            PickerRow(
                                title: "Height Unit",
                                selection: Binding<HeightUnit>(get: { heightUnit }, set: { heightUnitRaw = $0.rawValue }),
                                options: HeightUnit.allCases,
                                label: { $0 == .cm ? "cm" : "ft + in" }
                            )
                        }
                    }

                    // BODY
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Body Metrics").font(.headline)

                            // Current weight (kg/lbs aware)
                            if weightUnit == .kg {
                                NumericField(title: "Weight (kg)", value: $weightKg, formatter: numberFormatter)
                            } else {
                                NumericField(
                                    title: "Weight (lbs)",
                                    value: Binding(get: { kgToLbs(weightKg) }, set: { weightKg = lbsToKg($0) }),
                                    formatter: numberFormatter
                                )
                            }

                            // Starting / Goal weight
                            if weightUnit == .kg {
                                NumericField(title: "Starting weight (kg)", value: $startingWeightKg, formatter: numberFormatter)
                                NumericField(title: "Goal weight (kg)", value: $goalWeightKg, formatter: numberFormatter)
                            } else {
                                NumericField(
                                    title: "Starting weight (lbs)",
                                    value: Binding(get: { kgToLbs(startingWeightKg) }, set: { startingWeightKg = lbsToKg($0) }),
                                    formatter: numberFormatter
                                )
                                NumericField(
                                    title: "Goal weight (lbs)",
                                    value: Binding(get: { kgToLbs(goalWeightKg) }, set: { goalWeightKg = lbsToKg($0) }),
                                    formatter: numberFormatter
                                )
                            }

                            // Height (cm or ft+in) – itt is írható minden
                            if heightUnit == .cm {
                                NumericField(title: "Height (cm)", value: $heightCm, formatter: numberFormatter)
                            } else {
                                let ftIn = cmToFeetInches(heightCm)
                                HStack(spacing: 12) {
                                    IntEditorRowInline(title: "ft",
                                                       value: Binding(get: { feet == 0 ? ftIn.0 : feet },
                                                                      set: { feet = $0; heightCm = feetInchesToCm(feet: feet, inches: inches) }),
                                                       range: 3...8,
                                                       width: 56)

                                    NumericField(title: "in",
                                                 value: Binding(get: { inches == 0 ? ftIn.1 : inches },
                                                                set: {
                                                                    inches = max(0, min(11.99, $0))
                                                                    heightCm = feetInchesToCm(feet: feet, inches: inches)
                                                                }),
                                                 formatter: numberFormatter)
                                }
                                .onAppear { feet = ftIn.0; inches = ftIn.1 }
                            }
                        }
                    }

                    // GOALS
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Goals").font(.headline)

                            PickerRow(
                                title: "Primary Goal",
                                selection: Binding<Goal>(get: { goal }, set: { goalRaw = $0.rawValue }),
                                options: Goal.allCases,
                                label: { $0.rawValue }
                            )

                            PickerRow(
                                title: "Activity",
                                selection: Binding<ActivityLevel>(get: { activity }, set: { activityRaw = $0.rawValue }),
                                options: ActivityLevel.allCases,
                                label: { $0.rawValue }
                            )

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

                    // CALORIES PREVIEW
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calories (estimates)").font(.headline)

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

private struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content().padding(20) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
            .padding(.horizontal)
    }
}

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

/// Egységes INT sor: cím + beírható szám + stepper (– / +), tartományklampeléssel
private struct IntEditorRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
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

/// Ugyanez kompakt címkével (ft mezőhöz)
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

private struct StatRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }
    }
}

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
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

#Preview { SettingsView() }
