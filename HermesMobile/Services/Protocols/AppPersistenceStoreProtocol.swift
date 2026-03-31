import Foundation

@MainActor
protocol AppPersistenceStoreProtocol {
    func loadUserSettings() -> UserSettings?
    func saveUserSettings(_ settings: UserSettings)
    func loadSessionState() -> AppSessionState?
    func saveSessionState(_ state: AppSessionState)
    func loadInboxState() -> InboxLocalState
    func saveInboxState(_ state: InboxLocalState)
}
