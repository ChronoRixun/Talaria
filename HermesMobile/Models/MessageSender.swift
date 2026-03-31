import Foundation

enum MessageSender: String, Codable, Hashable, Sendable {
    case user
    case hermes
    case system
}
