import SwiftUI

// MARK: - Tab Definition

enum AppTab: String, CaseIterable, Identifiable {
    case chat
    case talk
    case inbox
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: "Chat"
        case .talk: "Talk"
        case .inbox: "Inbox"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .talk: "waveform.circle"
        case .inbox: "tray.full"
        case .settings: "gearshape"
        }
    }
}

// MARK: - Navigation Routes

enum Route: Hashable {
    case permissions
    case capture
    case connectHost
}

// MARK: - Sheet Destinations

enum SheetDestination: Identifiable {
    case conversationList
    case newConversation
    case inboxItemDetail(InboxItem)

    var id: String {
        switch self {
        case .conversationList: "conversationList"
        case .newConversation: "newConversation"
        case .inboxItemDetail(let item): "inboxItemDetail-\(item.id)"
        }
    }
}

// MARK: - Tab Router

@MainActor
@Observable
final class TabRouter {
    var selectedTab: AppTab = .chat
    var activeSheet: SheetDestination?
    private var paths: [AppTab: [Route]] = [:]

    func path(for tab: AppTab) -> [Route] {
        paths[tab, default: []]
    }

    func binding(for tab: AppTab) -> Binding<[Route]> {
        Binding(
            get: { self.paths[tab, default: []] },
            set: { self.paths[tab] = $0 }
        )
    }

    func navigate(to route: Route, in tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        paths[target, default: []].append(route)
    }

    func popToRoot(for tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        paths[target] = []
    }

    func resetAll() {
        paths.removeAll()
    }
}
