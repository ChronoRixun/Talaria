import Foundation

@MainActor
protocol AppPersistenceStoreProtocol {
    func loadUserSettings() -> UserSettings?
    func saveUserSettings(_ settings: UserSettings)
    func loadSessionState() -> AppSessionState?
    func saveSessionState(_ state: AppSessionState)
    func clearSessionState()
    func loadInboxState() -> InboxLocalState
    func saveInboxState(_ state: InboxLocalState)
    func clearInboxState()
    func loadPairedRelayConfiguration() -> PairedRelayConfiguration?
    func savePairedRelayConfiguration(_ configuration: PairedRelayConfiguration)
    func clearPairedRelayConfiguration()
}
