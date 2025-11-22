import SwiftUI

struct AddView: View {
    @StateObject private var viewModel = FoodViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                VStack(spacing: 32) {
                    // 🔹 Navigáció a ManualAddView-hoz
                    NavigationLink {
                        ManualAddView(viewModel: viewModel)
                    } label: {
                        VStack(spacing: 12) {
                            Text("🍽️").font(.system(size: 48))
                            Text("Add items manually").font(.headline)
                            Text("Log your meals manually.")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        .frame(width: 240, height: 160)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .shadow(radius: 4)
                    }

                    Button {
                        // camera action
                    } label: {
                        VStack(spacing: 12) {
                            Text("📷").font(.system(size: 48))
                            Text("Add items by camera").font(.headline)
                            Text("Log your meals by scanning qr code.")
                                .font(.subheadline)
                        }
                        .frame(width: 240, height: 160)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .shadow(radius: 4)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
