import Foundation

@MainActor
final class ResilientHermesClient: HermesClientProtocol {
    var connectionStatus: ConnectionStatus {
        primary.connectionStatus
    }

    var currentConversation: Conversation? {
        primary.currentConversation ?? fallback.currentConversation
    }

    private let primary: any HermesClientProtocol
    private let fallback: any HermesClientProtocol

    init(primary: any HermesClientProtocol, fallback: any HermesClientProtocol) {
        self.primary = primary
        self.fallback = fallback
    }

    func connect() async {
        await primary.connect()
        if primary.connectionStatus == .error {
            await fallback.connect()
        }
    }

    func disconnect() async {
        await primary.disconnect()
        await fallback.disconnect()
    }

    func send(message: String) async -> Message {
        let response = await primary.send(message: message)
        if response.status == .failed {
            return await fallback.send(message: message)
        }
        return response
    }

    func loadConversation() async -> Conversation {
        let conversation = await primary.loadConversation()
        if primary.connectionStatus == .error {
            return await fallback.loadConversation()
        }
        return conversation
    }
}
