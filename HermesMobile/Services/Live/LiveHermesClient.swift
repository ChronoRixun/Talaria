import Foundation

@MainActor
final class LiveHermesClient: HermesClientProtocol {
    private struct ConversationResponse: Decodable {
        let conversation: RelayConversation
    }

    private struct MessageResponse: Decodable {
        let conversation: RelayConversation
        let message: RelayMessage
    }

    private struct RelayConversation: Decodable {
        let id: UUID
        let title: String
        let updatedAt: Date
        let messages: [RelayMessage]
    }

    private struct RelayMessage: Decodable {
        let id: UUID
        let role: MessageSender
        let text: String
        let timestamp: Date
    }

    private struct MessageCreateBody: Encodable {
        let conversationId: UUID?
        let text: String
    }

    var connectionStatus: ConnectionStatus = .disconnected
    var currentConversation: Conversation?

    private let apiClient: RelayAPIClient
    private let accessTokenProvider: @MainActor () async -> String?

    init(
        apiClient: RelayAPIClient,
        accessTokenProvider: @escaping @MainActor () async -> String?
    ) {
        self.apiClient = apiClient
        self.accessTokenProvider = accessTokenProvider
    }

    func connect() async {
        connectionStatus = .connecting
        do {
            let token = await accessTokenProvider()
            let response: ConversationResponse = try await apiClient.get(
                path: "conversations/current",
                accessToken: token
            )
            currentConversation = mapConversation(response.conversation)
            connectionStatus = .connected
        } catch {
            connectionStatus = .error
        }
    }

    func disconnect() async {
        connectionStatus = .disconnected
    }

    func send(message: String) async -> Message {
        do {
            let token = await accessTokenProvider()
            let response: MessageResponse = try await apiClient.post(
                path: "messages",
                body: MessageCreateBody(
                    conversationId: currentConversation?.id,
                    text: message
                ),
                accessToken: token
            )
            currentConversation = mapConversation(response.conversation)
            connectionStatus = .connected
            return mapMessage(response.message)
        } catch {
            connectionStatus = .error
            return Message(sender: .system, content: "Hermes relay is unavailable right now.", status: .failed)
        }
    }

    func loadConversation() async -> Conversation {
        do {
            let token = await accessTokenProvider()
            let response: ConversationResponse = try await apiClient.get(
                path: "conversations/current",
                accessToken: token
            )
            let conversation = mapConversation(response.conversation)
            currentConversation = conversation
            connectionStatus = .connected
            return conversation
        } catch {
            connectionStatus = .error
            return currentConversation ?? DemoData.sampleConversation
        }
    }

    private func mapConversation(_ relayConversation: RelayConversation) -> Conversation {
        Conversation(
            id: relayConversation.id,
            title: relayConversation.title,
            messages: relayConversation.messages.map(mapMessage),
            lastActivity: relayConversation.updatedAt
        )
    }

    private func mapMessage(_ relayMessage: RelayMessage) -> Message {
        Message(
            id: relayMessage.id,
            sender: relayMessage.role,
            content: relayMessage.text,
            timestamp: relayMessage.timestamp,
            status: relayMessage.role == .user ? .sent : .delivered
        )
    }
}
