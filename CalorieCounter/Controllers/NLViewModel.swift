import Foundation
import Combine

@MainActor
final class NLViewModel: ObservableObject {

    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    @Published var lastRawResponse: String = ""
    @Published var lastResponse: NLCommandResponse?

    private let endpoint = URL(string: "http://127.0.0.1:8000/nl-command")!

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        lastError = nil

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
                    lastRawResponse = raw
                    isLoading = false
                    return
                }

                let decoder = JSONDecoder()
                let parsed = try decoder.decode(NLCommandResponse.self, from: data)

                isLoading = false
                lastResponse = parsed
                if let jsonString = String(data: data, encoding: .utf8) {
                    lastRawResponse = jsonString
                }

                print("NLCommand response:", parsed)

            } catch {
                isLoading = false
                lastError = "Network/decoding error: \(error.localizedDescription)"
                print("Request failed:", error)
            }
        }
    }
}
