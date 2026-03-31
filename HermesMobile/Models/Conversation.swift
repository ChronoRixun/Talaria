import Foundation

struct Conversation: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var messages: [Message]
    var lastActivity: Date

    init(
        id: UUID = UUID(),
        title: String,
        messages: [Message] = [],
        lastActivity: Date = .now
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.lastActivity = lastActivity
    }

    var lastMessage: Message? {
        messages.last
    }

    var previewText: String {
        lastMessage?.content ?? "No messages yet"
    }
}
