import SwiftUI

struct AppRootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
            if !container.pairingStore.isPaired {
                ConnectHermesScreen()
            } else if container.pairingStore.needsPermissionsOnboarding {
                PermissionsOnboardingScreen()
            } else {
                MainTabView()
            }
        }
        .animation(Design.Motion.standard, value: container.pairingStore.isPaired)
        .animation(Design.Motion.standard, value: container.pairingStore.needsPermissionsOnboarding)
    }
}
