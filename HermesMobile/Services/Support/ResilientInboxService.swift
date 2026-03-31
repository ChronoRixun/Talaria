import Foundation

@MainActor
final class ResilientInboxService: InboxServiceProtocol {
    private let primary: any InboxServiceProtocol
    private let fallback: any InboxServiceProtocol

    init(primary: any InboxServiceProtocol, fallback: any InboxServiceProtocol) {
        self.primary = primary
        self.fallback = fallback
    }

    func fetchInbox(accessToken: String?) async throws -> [InboxItem] {
        do {
            return try await primary.fetchInbox(accessToken: accessToken)
        } catch {
            return try await fallback.fetchInbox(accessToken: accessToken)
        }
    }

    func submitAction(
        itemID: UUID,
        actionID: String,
        accessToken: String?
    ) async throws -> InboxActionResult {
        do {
            return try await primary.submitAction(itemID: itemID, actionID: actionID, accessToken: accessToken)
        } catch {
            return try await fallback.submitAction(itemID: itemID, actionID: actionID, accessToken: accessToken)
        }
    }
}
