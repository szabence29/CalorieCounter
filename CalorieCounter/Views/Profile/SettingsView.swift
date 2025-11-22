import SwiftUI

/// Teljesen Firestore-alapú Settings.
/// - A mezők egy `draft`-on keresztül szerkeszthetők
/// - Minden változás azonnal megy a Firestore-ba `store.update(fields:)`-szel
struct SettingsView: View {
    @EnvironmentObject var store: ProfileStore
    @State private var draft = UserProfile()

    // Opciók (string-alapú, hogy ne kelljen enumokat definiálnod külön)
    private let sexOptions = ["male", "female"]
    private let weightUnitOptions = ["kg", "lbs"]
    private let heightUnitOptions = ["cm", "ftIn"]
    private let activityOptions = ["Sedentary", "Lightly active", "Moderately active", "Very active", "Athlete"]
    private let goalOptions = ["Lose weight", "Maintain", "Gain muscle"]

    // Számformázó
    private let nf: NumberFormatter = {
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

                    // Cím
                    HStack {
                        Text("Settings").font(.system(size: 28, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal)

                    // PROFILE kártya
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Profile").font(.headline)

                            VStack(spacing: 12) {
                                // Név
                                LabeledTextField(
                                    title: "Name",
                                    text: Binding(
                                        get: { draft.name ?? "" },
                                        set: { let v = $0; draft.name = v; Task { await store.update(fields: ["name": v]) } }
                                    )
                                )

                                // Életkor
                                IntEditorRow(
                                    title: "Age",
                                    value: Binding(
                                        get: { draft.age ?? 0 },
                                        set: { let v = $0; draft.age = v; Task { await store.update(fields: ["age": v]) } }
                                    ),
                                    range: 10...100
                                )

                                // Nem
                                MenuPickerRow(
                                    title: "Sex",
                                    selection: Binding(
                                        get: { draft.sex ?? sexOptions.first! },
                                        set: { let v = $0; draft.sex = v; Task { await store.update(fields: ["sex": v]) } }
                                    ),
                                    options: sexOptions,
                                    label: { $0.capitalized }
                                )
                            }
                        }
                    }

                    // UNITS kártya
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Units").font(.headline)

                            MenuPickerRow(
                                title: "Weight Unit",
                                selection: Binding(
                                    get: { draft.weightUnit ?? weightUnitOptions.first! },
                                    set: { let v = $0; draft.weightUnit = v; Task { await store.update(fields: ["weightUnit": v]) } }
                                ),
                                options: weightUnitOptions,
                                label: { $0.uppercased() }
                            )

                            MenuPickerRow(
                                title: "Height Unit",
                                selection: Binding(
                                    get: { draft.heightUnit ?? heightUnitOptions.first! },
                                    set: { let v = $0; draft.heightUnit = v; Task { await store.update(fields: ["heightUnit": v]) } }
                                ),
                                options: heightUnitOptions,
                                label: { $0 == "cm" ? "cm" : "ft + in" }
                            )
                        }
                    }

                    // BODY METRICS kártya
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Body Metrics").font(.headline)

                            // Weight
                            if (draft.weightUnit ?? "kg") == "kg" {
                                NumericField(
                                    title: "Weight (kg)",
                                    value: Binding(
                                        get: { draft.weightKg ?? 0 },
                                        set: { let v = $0; draft.weightKg = v; Task { await store.update(fields: ["weightKg": v]) } }
                                    ),
                                    formatter: nf
                                )
                            } else {
                                NumericField(
                                    title: "Weight (lbs)",
                                    value: Binding(
                                        get: { kgToLbs(draft.weightKg ?? 0) },
                                        set: { let kg = lbsToKg($0); draft.weightKg = kg; Task { await store.update(fields: ["weightKg": kg]) } }
                                    ),
                                    formatter: nf
                                )
                            }

                            // Starting / Goal
                            if (draft.weightUnit ?? "kg") == "kg" {
                                NumericField(
                                    title: "Starting weight (kg)",
                                    value: Binding(
                                        get: { draft.startingWeightKg ?? 0 },
                                        set: { let v = $0; draft.startingWeightKg = v; Task { await store.update(fields: ["startingWeightKg": v]) } }
                                    ),
                                    formatter: nf
                                )
                                NumericField(
                                    title: "Goal weight (kg)",
                                    value: Binding(
                                        get: { draft.goalWeightKg ?? 0 },
                                        set: { let v = $0; draft.goalWeightKg = v; Task { await store.update(fields: ["goalWeightKg": v]) } }
                                    ),
                                    formatter: nf
                                )
                            } else {
                                NumericField(
                                    title: "Starting weight (lbs)",
                                    value: Binding(
                                        get: { kgToLbs(draft.startingWeightKg ?? 0) },
                                        set: { let kg = lbsToKg($0); draft.startingWeightKg = kg; Task { await store.update(fields: ["startingWeightKg": kg]) } }
                                    ),
                                    formatter: nf
                                )
                                NumericField(
                                    title: "Goal weight (lbs)",
                                    value: Binding(
                                        get: { kgToLbs(draft.goalWeightKg ?? 0) },
                                        set: { let kg = lbsToKg($0); draft.goalWeightKg = kg; Task { await store.update(fields: ["goalWeightKg": kg]) } }
                                    ),
                                    formatter: nf
                                )
                            }

                            // Height
                            if (draft.heightUnit ?? "cm") == "cm" {
                                NumericField(
                                    title: "Height (cm)",
                                    value: Binding(
                                        get: { draft.heightCm ?? 0 },
                                        set: { let v = $0; draft.heightCm = v; Task { await store.update(fields: ["heightCm": v]) } }
                                    ),
                                    formatter: nf
                                )
                            } else {
                                // ft + in szerkesztés → cm-be írunk vissza
                                let ftIn = cmToFeetInches(draft.heightCm ?? 0)
                                HStack(spacing: 12) {
                                    IntEditorRowInline(
                                        title: "ft",
                                        value: Binding(
                                            get: { ftIn.0 },
                                            set: { newFeet in
                                                let cm = feetInchesToCm(feet: newFeet, inches: ftIn.1)
                                                draft.heightCm = cm
                                                Task { await store.update(fields: ["heightCm": cm]) }
                                            }
                                        ),
                                        range: 3...8,
                                        width: 56
                                    )
                                    NumericField(
                                        title: "in",
                                        value: Binding(
                                            get: { ftIn.1 },
                                            set: { newIn in
                                                let inchesClamped = max(0, min(11.99, newIn))
                                                let cm = feetInchesToCm(feet: ftIn.0, inches: inchesClamped)
                                                draft.heightCm = cm
                                                Task { await store.update(fields: ["heightCm": cm]) }
                                            }
                                        ),
                                        formatter: nf
                                    )
                                }
                            }
                        }
                    }

                    // GOALS kártya
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Goals").font(.headline)

                            MenuPickerRow(
                                title: "Primary Goal",
                                selection: Binding(
                                    get: { draft.goal ?? goalOptions[1] /* Maintain */ },
                                    set: { let v = $0; draft.goal = v; Task { await store.update(fields: ["goal": v]) } }
                                ),
                                options: goalOptions,
                                label: { $0 }
                            )

                            MenuPickerRow(
                                title: "Activity",
                                selection: Binding(
                                    get: { draft.activity ?? activityOptions[2] /* Moderately active */ },
                                    set: { let v = $0; draft.activity = v; Task { await store.update(fields: ["activity": v]) } }
                                ),
                                options: activityOptions,
                                label: { $0 }
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                let label: String = {
                                    switch (draft.goal ?? "Maintain") {
                                        case "Lose weight": return "Weekly loss (kg/wk)"
                                        case "Gain muscle": return "Weekly gain (kg/wk)"
                                        default: return "Adjustment (kg/wk)"
                                    }
                                }()
                                NumericField(
                                    title: label,
                                    value: Binding(
                                        get: { draft.weeklyDeltaKg ?? 0 },
                                        set: { let v = $0; draft.weeklyDeltaKg = v; Task { await store.update(fields: ["weeklyDeltaKg": v]) } }
                                    ),
                                    formatter: nf
                                )

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

                            let b = bmr(
                                sex: draft.sex ?? "male",
                                weightKg: draft.weightKg ?? 0,
                                heightCm: draft.heightCm ?? 0,
                                age: draft.age ?? 0
                            )
                            let t = tdee(bmr: b, activity: draft.activity ?? "Moderately active")
                            let target = adjustedCalories(tdee: t, weeklyDeltaKg: draft.weeklyDeltaKg ?? 0)

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
        .task {
            // draft inicializálása Firestore-ból
            draft = store.profile
        }
        .onChange(of: store.profile) { _, p in
            // Ha más eszközről változik, tükrözzük
            draft = p
        }
    }

    // MARK: - Helpers (lokális, string-alapú)

    private func kgToLbs(_ kg: Double) -> Double { kg * 2.2046226218 }
    private func lbsToKg(_ lbs: Double) -> Double { lbs / 2.2046226218 }

    private func cmToFeetInches(_ cm: Double) -> (Int, Double) {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12.0)
        let inches = totalInches - Double(feet) * 12.0
        return (feet, inches)
    }
    private func feetInchesToCm(feet: Int, inches: Double) -> Double {
        (Double(feet) * 12.0 + inches) * 2.54
    }

    // BMR / TDEE / Suggested calories (string-alapú „sex” & „activity”)
    private func bmr(sex: String, weightKg: Double, heightCm: Double, age: Int) -> Double {
        if sex.lowercased() == "female" {
            return 10*weightKg + 6.25*heightCm - 5*Double(age) - 161
        } else {
            return 10*weightKg + 6.25*heightCm - 5*Double(age) + 5
        }
    }
    private func tdee(bmr: Double, activity: String) -> Double {
        let f: Double = {
            switch activity {
                case "Sedentary": return 1.2
                case "Lightly active": return 1.375
                case "Moderately active": return 1.55
                case "Very active": return 1.725
                case "Athlete": return 1.9
                default: return 1.55
            }
        }()
        return bmr * f
    }
    private func adjustedCalories(tdee: Double, weeklyDeltaKg: Double) -> Double {
        tdee + (weeklyDeltaKg * 7700.0) / 7.0
    }
}

// MARK: - Reusable UI (lokális másolatok, hogy önállóan forduljon)

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
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

private struct MenuPickerRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    var options: [T]
    var label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Menu {
                ForEach(options, id: \.self) { opt in
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

#Preview { SettingsView().environmentObject(ProfileStore()) }
