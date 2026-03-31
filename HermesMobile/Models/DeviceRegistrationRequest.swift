import Foundation

struct DeviceRegistrationRequest: Codable, Hashable, Sendable {
    let installationID: UUID
    let deviceName: String
    let appVersion: String
    let buildNumber: String
    let bundleID: String
    let deviceModel: String
    let systemVersion: String
    let environment: AppEnvironment
}
