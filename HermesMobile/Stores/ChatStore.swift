import Foundation

@MainActor
@Observable
final class ChatStore {
    var conversation: Conversation?
    var isLoading = false

    private let hermesClient: any HermesClientProtocol

    init(hermesClient: any HermesClientProtocol) {
        self.hermesClient = hermesClient
    }

    func loadConversationIfNeeded() async {
        guard conversation == nil else { return }
        await loadConversation()
    }

    func loadConversation() async {
        isLoading = true
        defer { isLoading = false }
        conversation = await hermesClient.loadConversation()
    }

    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let _ = await hermesClient.send(message: content)
        conversation = hermesClient.currentConversation
    }
}
