import Foundation

/// Minimal role set for the in-app conversation transcript.
enum ChatRole: String {
    case assistant
    case user
    case system
}

/// Conversation item rendered in the transcript column.
struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: ChatRole
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), role: ChatRole, text: String, timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
