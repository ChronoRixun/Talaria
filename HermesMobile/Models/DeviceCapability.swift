import Foundation

struct DeviceCapability: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let permissionType: PermissionType
    var status: PermissionStatus

    init(
        id: UUID = UUID(),
        permissionType: PermissionType,
        status: PermissionStatus = .notDetermined
    ) {
        self.id = id
        self.permissionType = permissionType
        self.status = status
    }
}
