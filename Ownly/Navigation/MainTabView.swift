import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label(AppState.Tab.dashboard.title, systemImage: AppState.Tab.dashboard.icon)
            }
            .tag(AppState.Tab.dashboard)

            NavigationStack {
                AssetListView()
            }
            .tabItem {
                Label(AppState.Tab.assets.title, systemImage: AppState.Tab.assets.icon)
            }
            .tag(AppState.Tab.assets)

            NavigationStack {
                ScannerView()
            }
            .tabItem {
                Label(AppState.Tab.scan.title, systemImage: AppState.Tab.scan.icon)
            }
            .tag(AppState.Tab.scan)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppState.Tab.settings.title, systemImage: AppState.Tab.settings.icon)
            }
            .tag(AppState.Tab.settings)
        }
        .tint(Color.ownlyPrimary)
    }
}
