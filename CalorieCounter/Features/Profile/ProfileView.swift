import SwiftUI
import PhotosUI

struct ProfileView: View {
    // Shared, persistent fields (AZONOS kulcsok!)
    @AppStorage("name") private var name: String = "Alex Johnson"
    @AppStorage("age") private var age: Int = 28
    @AppStorage("sex") private var sexRaw: String = Sex.male.rawValue

    @AppStorage("weightKg") private var weightKg: Double = 80
    @AppStorage("heightCm") private var heightCm: Double = 178
    @AppStorage("startingWeightKg") private var startingWeightKg: Double = 84
    @AppStorage("goalWeightKg") private var goalWeightKg: Double = 75

    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @AppStorage("heightUnit") private var heightUnitRaw: String = HeightUnit.cm.rawValue

    // UI-only
    @State private var streakDays: Int = 28
    @State private var startedDate: Date = ISO8601DateFormatter().date(from: "2023-06-10T00:00:00Z") ?? .now

    // Image picking
    @State private var profileImage: Image? = Image(systemName: "person.crop.circle.fill")
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var inputImage: UIImage? = nil
    @State private var showingCamera = false

    // Units & derived
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    private var heightUnit: HeightUnit { HeightUnit(rawValue: heightUnitRaw) ?? .cm }
    private var sex: Sex { Sex(rawValue: sexRaw) ?? .male }

    private var percentToGoal: Double {
        let total = abs(startingWeightKg - goalWeightKg)
        guard total > 0 else { return 1 }
        let done = abs(startingWeightKg - weightKg)
        return min(max(done / total, 0), 1)
    }

    private func weightText(from kg: Double) -> (String, String) {
        switch weightUnit {
        case .kg:  return ("\(Int(round(kg)))", "kg")
        case .lbs: return ("\(Int(round(kgToLbs(kg))))", "lbs")
        }
    }
    private var heightText: String {
        switch heightUnit {
        case .cm:   return "\(Int(round(heightCm))) cm"
        case .ftIn: let (f, i) = cmToFeetInches(heightCm); return "\(f)′ \(Int(round(i)))″"
        }
    }

    struct DayProgress: Identifiable { let id = UUID(); let label: String; let value: Double; let metGoal: Bool }
    @State private var week: [DayProgress] = [
        .init(label: "M", value: 0.8, metGoal: true),
        .init(label: "T", value: 0.75, metGoal: true),
        .init(label: "W", value: 0.7, metGoal: true),
        .init(label: "T", value: 0.45, metGoal: false),
        .init(label: "F", value: 0.6, metGoal: true),
        .init(label: "S", value: 0.4, metGoal: false),
        .init(label: "S", value: 0.5, metGoal: false),
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        HStack { Text("Profile").font(.system(size: 28, weight: .bold)); Spacer() }
                            .padding(.horizontal)

                        // Profile card
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 16) {
                                ZStack {
                                    profileImage?
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                    Circle().strokeBorder(Color(.systemGray5), lineWidth: 1)
                                        .frame(width: 64, height: 64)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(name).font(.system(size: 18, weight: .semibold))
                                    HStack(spacing: 6) {
                                        Text("\(streakDays) day streak").foregroundStyle(.secondary).font(.subheadline)
                                        Image(systemName: "flame.fill").foregroundStyle(.orange).font(.subheadline)
                                    }
                                    Text("Age \(age) · \(sex.rawValue.capitalized)")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(heightText).font(.caption).foregroundStyle(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 10) {
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        CircleIcon(systemName: "photo.fill.on.rectangle.fill")
                                    }
                                    Button { showingCamera.toggle() } label: { CircleIcon(systemName: "camera.fill") }
                                }
                            }

                            let start = weightText(from: startingWeightKg)
                            let curr  = weightText(from: weightKg)
                            let goal  = weightText(from: goalWeightKg)

                            HStack {
                                StatColumn(title: "Starting", value: start.0, unit: start.1)
                                Spacer()
                                StatColumn(title: "Current",  value: curr.0,  unit: curr.1)
                                Spacer()
                                StatColumn(title: "Goal",     value: goal.0,  unit: goal.1)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Capsule()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)
                                    .overlay(alignment: .leading) {
                                        GeometryReader { geo in
                                            let w = geo.size.width * percentToGoal
                                            Capsule().fill(Color.green).frame(width: w)
                                        }
                                    }

                                HStack(spacing: 8) {
                                    Text("\(Int(percentToGoal * 100))").font(.subheadline)
                                    Text("% to goal · Started").font(.subheadline).foregroundStyle(.secondary)
                                    Text(startedDate, style: .date).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(20)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
                        .padding(.horizontal)

                        // Weekly progress (dummy)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Weekly Progress").font(.headline)
                                Spacer()
                                Text("Last 7 days").font(.subheadline).foregroundStyle(.secondary)
                            }
                            HStack(alignment: .bottom, spacing: 14) {
                                ForEach(week) { day in
                                    VStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(day.metGoal ? Color.green : Color.orange)
                                            .frame(width: 22, height: max(12, 120 * day.value))
                                        Text(day.label).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                        }
                        .padding(20)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
                        .padding(.horizontal)

                        // Rows
                        VStack(spacing: 12) {
                            NavRow(icon: "chart.bar.doc.horizontal", tint: Color.blue.opacity(0.8), title: "Nutrition Goals")
                            NavRow(icon: "chart.line.uptrend.xyaxis", tint: Color.orange.opacity(0.9), title: "Progress Reports")
                            NavigationLink { SettingsView() } label: { NavRow(icon: "gearshape.fill", tint: .gray, title: "Settings") }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 28)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCamera) { CameraPicker(image: $inputImage) }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) { inputImage = uiImage }
            }
        }
        .onChange(of: inputImage) { loadImage() }
    }

    private func loadImage() {
        guard let inputImage else { return }
        profileImage = Image(uiImage: inputImage)
    }
}

// MARK: - Subviews

private struct StatColumn: View {
    let title: String, value: String, unit: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 20, weight: .semibold))
                Text(unit).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct CircleIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.subheadline)
            .padding(8)
            .background(.white)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }
}

private struct NavRow: View {
    let icon: String, tint: Color, title: String
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.15))
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)
            Text(title).font(.system(size: 16, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}

// Camera picker
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage { parent.image = uiImage }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview { ProfileView() }
