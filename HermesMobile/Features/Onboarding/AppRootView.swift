import SwiftUI

struct AppRootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
            if container.pairingStore.isPaired {
                MainTabView()
            } else {
                ConnectHermesScreen()
            }
        }
        .animation(Design.Motion.standard, value: container.pairingStore.isPaired)
    }
}
