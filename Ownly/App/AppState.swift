import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    enum AuthState: Equatable {
        case loading
        case unauthenticated
        case guest
        case authenticated(userId: String)
    }

    @Published var authState: AuthState = .loading
    @Published var isOnline: Bool = true
    @Published var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard
        case assets
        case scan
        case settings

        var title: String {
            switch self {
            case .dashboard: return String(localized: "tab.dashboard")
            case .assets: return String(localized: "tab.assets")
            case .scan: return String(localized: "tab.scan")
            case .settings: return String(localized: "tab.settings")
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .assets: return "cube.fill"
            case .scan: return "doc.text.viewfinder"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }

    var isGuest: Bool {
        if case .guest = authState { return true }
        return false
    }

    var currentUserId: String? {
        if case .authenticated(let userId) = authState { return userId }
        return nil
    }
}
