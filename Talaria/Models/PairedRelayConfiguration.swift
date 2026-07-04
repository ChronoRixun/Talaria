import Foundation

struct PairedRelayConfiguration: Codable, Hashable, Sendable {
    let baseURLString: String
    let hostDisplayName: String
    let pairedAt: Date
    /// The relay user this pairing minted (#3/#46). Restored sessions are
    /// validated against it so a Keychain-resurrected identity from a previous
    /// install can't silently authenticate as the wrong user. Optional —
    /// pairings saved before this field existed decode as nil (no validation
    /// possible until the next re-pair records it).
    var relayUserID: UUID?
}
