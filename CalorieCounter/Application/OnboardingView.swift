import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ProfileStore

    // Onboarding egy “lokális draft”: csak Continue-nál mentünk store-ba.
    @State private var name: String = ""
    @State private var age: Int = 18
    @State private var sex: String = "male"
    @State private var heightCm: Double = 175
    @State private var weightKg: Double = 70
    @State private var goal: String = "Maintain"

    private let sexOptions = ["male", "female"]
    private let goalOptions = ["Lose weight", "Maintain", "Gain muscle"]

    private let nf: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        return nf
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Welcome! 👋").font(.system(size: 28, weight: .bold))
                    Text("Provide some information to get started!")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                Form {
                    Section("Profile") {
                        TextField("Name", text: $name)
                        Stepper(value: $age, in: 10...100) {
                            HStack { Text("Age"); Spacer(); Text("\(age)") }
                        }
                        Picker("Sex", selection: $sex) {
                            ForEach(sexOptions, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                    }

                    Section("Body metrics") {
                        HStack {
                            Text("Height (cm)")
                            Spacer()
                            TextField("cm", value: $heightCm, formatter: nf)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Weight (kg)")
                            Spacer()
                            TextField("kg", value: $weightKg, formatter: nf)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }

                    Section("Goal") {
                        Picker("Primary Goal", selection: $goal) {
                            ForEach(goalOptions, id: \.self) { Text($0) }
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                Button(action: complete) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.4) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding([.horizontal, .bottom], 16)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear { preloadFromProfile() }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled() // amíg nincs kitöltve, ne lehessen lehúzni
    }

    private func preloadFromProfile() {
        // Ha van már profil (pl. visszatérő user), töltsük elő a mezőket.
        let p = store.profile
        if let n = p.name, !n.isEmpty { name = n }
        if let a = p.age, a > 0 { age = a }
        if let s = p.sex, !s.isEmpty { sex = s }
        if let h = p.heightCm, h > 0 { heightCm = h }
        if let w = p.weightKg, w > 0 { weightKg = w }
        if let g = p.goal, !g.isEmpty { goal = g }
    }

    private func complete() {
        // Mentés a store-ba + flag(ek), majd dismiss.
        Task {
            await store.update(fields: [
                "name": name,
                "age": age,
                "sex": sex,
                "heightCm": heightCm,
                "weightKg": weightKg,
                "goal": goal,
                "weightUnit": "kg",
                "heightUnit": "cm",
                "onboardingCompleted": true
            ])
            await store.markOnboardingCompleted()
            dismiss()
        }
    }
}

#Preview {
    OnboardingView().environmentObject(ProfileStore())
}
