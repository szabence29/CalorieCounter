import SwiftUI
import PhotosUI
import FirebaseAuth
import GoogleSignIn
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var store: ProfileStore

    @State private var streakDays: Int = 28
    @State private var startedDate: Date = ISO8601DateFormatter().date(from: "2023-06-10T00:00:00Z") ?? .now

    @State private var profileImage: Image? = Image(systemName: "person.crop.circle.fill")
    @State private var selectedItem: PhotosPickerItem?
    @State private var inputImage: UIImage?
    @State private var showingCamera = false

    @State private var showAlert = false
    @State private var alertMessage = ""

    private var name: String { store.profile.name ?? "—" }
    private var ageText: String {
        let age = store.profile.age ?? 0
        let sexCap = (store.profile.sex ?? "").capitalized
        return age == 0 ? sexCap : "Age \(age) · \(sexCap)"
    }
    private var weightUnit: String { store.profile.weightUnit ?? "kg" }
    private var heightUnit: String { store.profile.heightUnit ?? "cm" }

    private var percentToGoal: Double {
        let start = store.profile.startingWeightKg ?? .nan
        let goal  = store.profile.goalWeightKg ?? .nan
        let curr  = store.profile.weightKg ?? .nan
        guard start.isFinite, goal.isFinite, curr.isFinite else { return 0 }
        let total = abs(start - goal)
        if total <= 0 { return 1 }
        let done = abs(start - curr)
        return min(max(done / total, 0), 1)
    }

    private func kgToLbs(_ kg: Double) -> Double { kg * 2.2046226218 }
    private func weightText(from kgOpt: Double?) -> (String, String) {
        guard let kg = kgOpt else { return ("—", weightUnit) }
        switch weightUnit {
        case "kg":  return ("\(Int(round(kg)))", "kg")
        case "lbs": return ("\(Int(round(kgToLbs(kg))))", "lbs")
        default:    return ("\(Int(round(kg)))", weightUnit.uppercased())
        }
    }
    private var heightText: String {
        let cm = store.profile.heightCm ?? .nan
        guard cm.isFinite else { return "—" }
        switch heightUnit {
        case "cm":
            return "\(Int(round(cm))) cm"
        case "ftIn":
            let totalInches = cm / 2.54
            let feet = Int(totalInches / 12.0)
            let inches = totalInches - Double(feet) * 12.0
            return "\(feet)′ \(Int(round(inches)))″"
        default:
            return "\(Int(round(cm))) \(heightUnit)"
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Fejléc
                        HStack {
                            Text("Profile")
                                .font(.system(size: 28, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal)

                        // Profil kártya
                        VStack(alignment: .leading, spacing: 18) {

                            HStack(spacing: 16) {
                                ZStack {
                                    profileImage?
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                    Circle()
                                        .strokeBorder(Color(.systemGray5), lineWidth: 1)
                                        .frame(width: 64, height: 64)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(name).font(.system(size: 18, weight: .semibold))

                                    HStack(spacing: 6) {
                                        Text("\(streakDays) day streak")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(.orange)
                                            .font(.subheadline)
                                    }

                                    Text(ageText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(heightText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 10) {
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        CircleIcon(systemName: "photo.fill.on.rectangle.fill")
                                    }
                                    Button { showingCamera.toggle() } label: {
                                        CircleIcon(systemName: "camera.fill")
                                    }
                                }
                            }

                            let start = weightText(from: store.profile.startingWeightKg)
                            let curr  = weightText(from: store.profile.weightKg)
                            let goal  = weightText(from: store.profile.goalWeightKg)

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
                                            Capsule()
                                                .fill(Color.green)
                                                .frame(width: w)
                                        }
                                    }

                                HStack(spacing: 8) {
                                    Text("\(Int(percentToGoal * 100))")
                                        .font(.subheadline)
                                    Text("% to goal · Started")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(startedDate, style: .date)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(20)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
                        .padding(.horizontal)

                        // Weekly progress
                        //WeeklyProgressCard(dailyGoal: store.suggestedDailyCalories ?? 2200)
                        
                        // Navigáció + Sign out
                        VStack(spacing: 12) {
                            //NavRow(icon: "chart.bar.doc.horizontal",
                            //       tint: Color.blue.opacity(0.8),
                            //       title: "Nutrition Goals")

                            //NavRow(icon: "chart.line.uptrend.xyaxis",
                            //       tint: Color.orange.opacity(0.9),
                            //       title: "Progress Reports")

                            NavigationLink { SettingsView() } label: {
                                NavRow(icon: "gearshape.fill", tint: .gray, title: "Settings")
                            }

                            // SIGN OUT gomb
                            Button(role: .destructive, action: signOut) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().fill(Color.red.opacity(0.12))
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.red)
                                    }
                                    .frame(width: 36, height: 36)

                                    Text("Sign out")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.red)
                                    Spacer()
                                }
                                .padding(14)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            }
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
                   let uiImage = UIImage(data: data) {
                    inputImage = uiImage
                }
            }
        }
        .onChange(of: inputImage) { loadImage() }
        .alert("Sign out error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(alertMessage) }
    }

    private func loadImage() {
        guard let inputImage else { return }
        profileImage = Image(uiImage: inputImage)
    }

    private func signOut() {
        do {
            store.logoutReset()
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
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
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)

            Text(title).font(.system(size: 16, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}

private struct WeeklyProgressCard: View {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Progress").font(.headline)
                Spacer()
                Text("Last 7 days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(week) { day in
                    VStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(day.metGoal ? Color.green : Color.orange)
                            .frame(width: 22, height: max(12, 120 * day.value))
                        Text(day.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
    }
}

// Kamera picker
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

#Preview { ProfileView().environmentObject(ProfileStore()) }
