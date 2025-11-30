import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage
    let onItemTap: (NLCommandResponse.Entities.Item, String?, String?) -> Void   // 👈

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                userBubble
            } else {
                assistantBubble
                Spacer()
            }
        }
        .id(message.id)
    }

    private var userBubble: some View {
        Text(message.text)
            .font(.body)
            .padding(10)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 260, alignment: .trailing)
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let parsed = message.parsed,
               let original = message.originalText {
                AssistantParsedView(
                    originalText: original,
                    response: parsed,
                    onItemTap: onItemTap
                )
            } else {
                Text(message.text)
                    .font(.body)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .foregroundColor(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 300, alignment: .leading)
    }
}
