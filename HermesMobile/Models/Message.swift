import Foundation

struct Message: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let sender: MessageSender
    let content: String
    let timestamp: Date
    var status: MessageStatus

    init(
        id: UUID = UUID(),
        sender: MessageSender,
        content: String,
        timestamp: Date = .now,
        status: MessageStatus = .sent
    ) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.status = status
    }
}
