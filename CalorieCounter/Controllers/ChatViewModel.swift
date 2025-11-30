import Foundation
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let originalText: String?
    let parsed: NLCommandResponse?
}

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    @Published var messages: [ChatMessage] = []

    private let endpoint = URL(string: "http://127.0.0.1:8000/nl-command")!

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lastError = nil

        let userMessage = ChatMessage(
            isUser: true,
            text: trimmed,
            originalText: nil,
            parsed: nil
        )
        messages.append(userMessage)

        inputText = ""
        isLoading = true

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["text": trimmed]

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            isLoading = false
            lastError = "Encoding error: \(error.localizedDescription)"
            print("Encoding error:", error)
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                if let http = response as? HTTPURLResponse,
                   !(200..<300).contains(http.statusCode) {
                    let raw = String(data: data, encoding: .utf8) ?? "<no body>"
                    print("Server error \(http.statusCode):\n\(raw)")
                    lastError = "Server error: \(http.statusCode)"
                    isLoading = false
                    return
                }

                let decoder = JSONDecoder()
                let parsed = try decoder.decode(NLCommandResponse.self, from: data)
                isLoading = false

                let summary = Self.formatSummary(from: parsed)

                let assistantMessage = ChatMessage(
                    isUser: false,
                    text: summary,
                    originalText: trimmed,
                    parsed: parsed
                )
                messages.append(assistantMessage)

                print("Parsed:", parsed)

            } catch {
                isLoading = false
                lastError = "Network/decoding error: \(error.localizedDescription)"
                print("Request failed:", error)
            }
        }
    }

    private static func formatSummary(from response: NLCommandResponse) -> String {
        var parts: [String] = []

        if !response.entities.items.isEmpty {
            let itemsLines = response.entities.items.map { item in
                let qty = item.quantity.map { Int($0) } ?? 0
                let unit = item.unit ?? ""
                return "• \(item.name) – \(qty) \(unit)"
            }.joined(separator: "\n")
            parts.append("Items:\n\(itemsLines)")
        }

        if let meal = response.entities.meal {
            parts.append("Meal: \(meal)")
        }

        if let date = response.entities.date {
            parts.append("Date: \(date)")
        }

        if !response.missing_fields.isEmpty {
            parts.append("Missing: \(response.missing_fields.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n\n")
    }
}
