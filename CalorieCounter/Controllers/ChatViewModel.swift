import Foundation
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String

    // Debug/trace: ugyanaz a user input visszacsatolva, ha később kell összevetni a parse-szal.
    let originalText: String?

    // A backend által visszaadott strukturált értelmezés (ha kell UI-hoz / későbbi action-ökhöz).
    let parsed: NLCommandResponse?
}

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var messages: [ChatMessage] = []

    // Deployolt NL endpoint
    private let endpoint = URL(string: "https://caloriecounter-45of.onrender.com/nl-command")!

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lastError = nil

        messages.append(ChatMessage(
            isUser: true,
            text: trimmed,
            originalText: nil,
            parsed: nil
        ))

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
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                if let http = response as? HTTPURLResponse,
                   !(200..<300).contains(http.statusCode) {
                    lastError = "Server error: \(http.statusCode)"
                    isLoading = false
                    return
                }

                let parsed = try JSONDecoder().decode(NLCommandResponse.self, from: data)
                isLoading = false

                // UI-barát összefoglaló: a strukturált válaszból emberi “preview” szöveg.
                let summary = Self.formatSummary(from: parsed)

                messages.append(ChatMessage(
                    isUser: false,
                    text: summary,
                    originalText: trimmed,
                    parsed: parsed
                ))

            } catch {
                isLoading = false
                lastError = "Network/decoding error: \(error.localizedDescription)"
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

        if let meal = response.entities.meal { parts.append("Meal: \(meal)") }
        if let date = response.entities.date { parts.append("Date: \(date)") }

        if !response.missing_fields.isEmpty {
            parts.append("Missing: \(response.missing_fields.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n\n")
    }
}
