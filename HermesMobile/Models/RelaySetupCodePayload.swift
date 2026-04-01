import Foundation

enum RelaySetupCodeError: LocalizedError {
    case unsupportedVersion
    case invalidPayload
    case invalidRelayURL

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            "This setup code uses an unsupported version."
        case .invalidPayload:
            "This setup code is invalid."
        case .invalidRelayURL:
            "This setup code does not contain a valid Hermes relay URL."
        }
    }
}

struct RelaySetupCodePayload: Codable, Hashable, Sendable {
    static let prefix = "HM1:"

    let relayURL: String
    let inviteToken: String
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case relayURL = "relay_url"
        case inviteToken = "invite_token"
        case expiresAt = "expires_at"
    }

    var hostDisplayName: String {
        URL(string: relayURL)?.host ?? relayURL
    }

    static func decode(from rawCode: String) throws -> RelaySetupCodePayload {
        let trimmed = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else {
            throw RelaySetupCodeError.unsupportedVersion
        }

        let encoded = String(trimmed.dropFirst(prefix.count))
        let base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64.padding(
            toLength: ((encoded.count + 3) / 4) * 4,
            withPad: "=",
            startingAt: 0
        )

        guard
            let data = Data(base64Encoded: padded, options: [.ignoreUnknownCharacters])
        else {
            throw RelaySetupCodeError.invalidPayload
        }

        let decoder = RelayCoders.makeDecoder()

        let payload: RelaySetupCodePayload
        do {
            payload = try decoder.decode(RelaySetupCodePayload.self, from: data)
        } catch {
            throw RelaySetupCodeError.invalidPayload
        }

        guard
            let url = URL(string: payload.relayURL),
            let scheme = url.scheme,
            ["http", "https"].contains(scheme),
            url.host != nil
        else {
            throw RelaySetupCodeError.invalidRelayURL
        }

        return payload
    }
}
