import SwiftUI

struct AddView: View {
    @State private var showSheet = false
    @StateObject private var viewModel = FoodViewModel()

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            VStack(spacing: 32) {
                Button(action: {
                    viewModel.fetchFoods()
                    showSheet = true
                }) {
                    VStack(spacing: 12) {
                        Text("🍽️").font(.system(size: 48))
                        Text("Add items manually").font(.headline)
                        Text("Log your meals manually.").font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(width: 240, height: 160)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .shadow(radius: 4)
                }
                Button(action: {
                    // Action for camera add
                }) {
                    VStack(spacing: 12) {
                        Text("📷")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Add items by camera")
                            .font(.headline)
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
        .sheet(isPresented: $showSheet) {
            List(viewModel.items) { item in
                Text(item.description)
            }
        }
    }
}
