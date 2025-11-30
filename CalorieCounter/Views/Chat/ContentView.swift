import SwiftUI

struct ContentView: View {

    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedItem: NLCommandResponse.Entities.Item?
    @State private var selectedMeal: MealType = .breakfast
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatMessageRow(
                                message: message,
                                onItemTap: { item, mealString, dateString in
                                    selectedItem = item
                                    selectedMeal = MealType(fromNLString: mealString)

                                    if let ds = dateString {
                                        let fmt = DateFormatter()
                                        fmt.calendar = .init(identifier: .iso8601)
                                        fmt.locale = .init(identifier: "en_US_POSIX")
                                        fmt.dateFormat = "yyyy-MM-dd"
                                        selectedDate = fmt.date(from: ds) ?? Date()
                                    } else {
                                        selectedDate = Date()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("NLP")
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                if let error = viewModel.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                inputBar
            }
            .padding(.bottom, 4)
        }
        .sheet(item: $selectedItem) { item in
            FoodDetailLoaderSheet(
                nlpItem: item,
                defaultMeal: selectedMeal,
                defaultDate: selectedDate
            )
        }
    }

    private var inputBar: some View {
        HStack {
            HStack(spacing: 10) {
                TextField("Describe what you ate…",
                          text: $viewModel.inputText,
                          axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit {
                        viewModel.send()
                    }

                Button {
                    viewModel.send()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .disabled(!viewModel.canSend)
                .opacity(viewModel.canSend ? 1.0 : 0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
    }
}
