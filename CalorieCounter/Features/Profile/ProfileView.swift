import SwiftUI
import PhotosUI

struct ProfileView: View {
    @State private var name: String = "John Doe"
    @State private var age: String = "28"
    @State private var weight: String = "75"
    @State private var height: String = "178"
    @State private var goal: String = "Maintain weight"
    @State private var calorieGoal: Double = 2200
    @State private var caloriesConsumed: Double = 1200

    // Image picker states
    @State private var profileImage: Image? = Image(systemName: "person.circle.fill")
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var inputImage: UIImage? = nil
    @State private var showingCamera = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: Profile Image
                    VStack {
                        profileImage?
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                            .overlay(
                                // Camera / Gallery Buttons
                                HStack(spacing: 10) {
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        Image(systemName: "photo.fill.on.rectangle.fill")
                                            .padding(8)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .shadow(radius: 2)
                                    }
                                    
                                    Button(action: {
                                        showingCamera.toggle()
                                    }) {
                                        Image(systemName: "camera.fill")
                                            .padding(8)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .shadow(radius: 2)
                                    }
                                }
                                    .offset(y: 60)
                            )
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                    
                    // MARK: Editable User Info
                    VStack(alignment: .leading, spacing: 16) {
                        ProfileTextField(title: "Name", text: $name)
                        ProfileTextField(title: "Age", text: $age, keyboardType: .numberPad)
                        ProfileTextField(title: "Weight (kg)", text: $weight, keyboardType: .decimalPad)
                        ProfileTextField(title: "Height (cm)", text: $height, keyboardType: .decimalPad)
                        
                        Picker("Goal", selection: $goal) {
                            Text("Lose weight").tag("Lose weight")
                            Text("Maintain weight").tag("Maintain weight")
                            Text("Gain muscle").tag("Gain muscle")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 1)
                    
                    // MARK: Calorie Goal
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Calorie Goal")
                            .font(.headline)
                        ProgressView(value: caloriesConsumed, total: calorieGoal)
                            .accentColor(.green)
                        HStack {
                            Text("\(Int(caloriesConsumed)) kcal consumed")
                            Spacer()
                            Text("\(Int(calorieGoal)) kcal goal")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // MARK: Save Button
                    Button(action: {
                        // Save logic here
                    }) {
                        Text("Save Changes")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $inputImage)
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    inputImage = uiImage
                }
            }
        }
        .onChange(of: inputImage) {
            loadImage()
        }
    }

    func loadImage() {
        guard let inputImage = inputImage else { return }
        profileImage = Image(uiImage: inputImage)
    }
}

// MARK: - Profile TextField Subview
struct ProfileTextField: View {
    var title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

// MARK: - Camera Picker (UIKit Wrapper)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    ProfileView()
}
