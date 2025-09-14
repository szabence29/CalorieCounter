import SwiftUI

struct AddView: View {
    @State private var inputText: String = ""
    @State private var items: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Enter text...", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.top)

            Button(action: {
                let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    items.append(trimmed)
                    inputText = ""
                }
            }) {
                Text("Add")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            List(items, id: \.self) { item in
                Text(item)
            }
            .listStyle(PlainListStyle())

            Spacer()
        }
        .padding()
    }
}
