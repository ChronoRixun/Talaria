import SwiftUI

struct MainTabView: View {
    @Environment(TabRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Chat", systemImage: AppTab.chat.icon, value: .chat) {
                NavigationStack(path: router.binding(for: .chat)) {
                    ChatScreen()
                        .navigationDestination(for: Route.self) { route in
                            routeDestination(route)
                        }
                }
            }

            Tab("Talk", systemImage: AppTab.talk.icon, value: .talk) {
                NavigationStack(path: router.binding(for: .talk)) {
                    TalkModeScreen()
                        .navigationDestination(for: Route.self) { route in
                            routeDestination(route)
                        }
                }
            }

            Tab("Inbox", systemImage: AppTab.inbox.icon, value: .inbox) {
                NavigationStack(path: router.binding(for: .inbox)) {
                    InboxScreen()
                        .navigationDestination(for: Route.self) { route in
                            routeDestination(route)
                        }
                }
            }

            Tab("Settings", systemImage: AppTab.settings.icon, value: .settings) {
                NavigationStack(path: router.binding(for: .settings)) {
                    SettingsScreen()
                        .navigationDestination(for: Route.self) { route in
                            routeDestination(route)
                        }
                }
            }
        }
        .sheet(item: $router.activeSheet) { destination in
            sheetDestination(destination)
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: Route) -> some View {
        switch route {
        case .permissions:
            PermissionsScreen()
        case .capture:
            CaptureScreen()
        case .connectHost:
            ConnectHermesHostScreen()
        }
    }

    @ViewBuilder
    private func sheetDestination(_ destination: SheetDestination) -> some View {
        switch destination {
        case .conversationList:
            Text("Conversations")
                .font(Design.Typography.screenTitle)
        case .newConversation:
            Text("New Conversation")
                .font(Design.Typography.screenTitle)
        case .inboxItemDetail(let item):
            InboxItemDetailSheet(item: item)
        }
    }
}
