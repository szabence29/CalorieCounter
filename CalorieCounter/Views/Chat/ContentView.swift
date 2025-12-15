import SwiftUI

struct ContentView: View {

    @StateObject private var viewModel = ChatViewModel()

    // Az a tétel, amit a kártyáról kiválasztunk
    @State private var selectedItem: NLCommandResponse.Entities.Item?
    @State private var selectedMeal: MealType = .breakfast
    @State private var selectedDate: Date = Date()

    @FocusState private var isTextFocused: Bool

    // Csak az utolsó asszisztens-üzenet (nem mutatjuk a user buborékot)
    private var lastAssistantMessage: ChatMessage? {
        viewModel.messages.last(where: { !$0.isUser && $0.parsed != nil })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    instructionsCard

                    inputSection

                    if let message = lastAssistantMessage,
                       let parsed = message.parsed {

                        Text("Last result")
                            .font(.headline)
                            .padding(.top, 8)

                        AssistantParsedView(
                            originalText: message.originalText ?? message.text,
                            response: parsed,
                            onItemTap: { item, mealString, dateString in
                                handleItemTap(
                                    item: item,
                                    mealString: mealString,
                                    dateString: dateString
                                )
                            }
                        )
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("NLP")
            .background(Color(.systemBackground))
            .onTapGesture {
                // háttérre tappolva zárjuk a billentyűzetet
                isTextFocused = false
            }
            .toolbar {
                // Keyboard fölötti „Done”
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isTextFocused = false
                        }
                    }
                }
            }
            // Sheet a kiválasztott ételhez
            .sheet(item: $selectedItem) { item in
                FoodDetailLoaderSheet(
                    nlpItem: item,
                    defaultMeal: selectedMeal,
                    defaultDate: selectedDate
                )
            }
        }
    }

    // MARK: - Top instructions card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Describe what you ate")
                .font(.headline)
            Text("""
                 Type in natural language, for example:
                 • I ate an apple and a yogurt for breakfast
                 • Two slices of pizza and a cola for dinner
                 • Just a coffee and a cookie this afternoon
                 """)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Input + Send

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What did you eat?")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))

                TextEditor(text: $viewModel.inputText)
                    .focused($isTextFocused)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 110, maxHeight: 160)

                if viewModel.inputText.isEmpty {
                    Text("Describe what you ate…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
            }
            .frame(maxWidth: .infinity)

            Button(action: {
                isTextFocused = false
                viewModel.send()
            }) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                    Text("Send")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.canSend ? Color.accentColor : Color(.systemGray4))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!viewModel.canSend)
        }
    }

    // MARK: - Item tap → FoodDetailLoaderSheet

    private func handleItemTap(
        item: NLCommandResponse.Entities.Item,
        mealString: String?,
        dateString: String?
    ) {
        selectedItem = item
        selectedMeal = MealType(fromNLString: mealString)

        if let ds = dateString {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .iso8601)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy-MM-dd"
            selectedDate = df.date(from: ds) ?? Date()
        } else {
            selectedDate = Date()
        }
    }
}
