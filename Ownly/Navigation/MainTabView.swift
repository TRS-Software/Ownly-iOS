import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Tab(AppState.Tab.dashboard.title, systemImage: AppState.Tab.dashboard.icon, value: .dashboard) {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab(AppState.Tab.assets.title, systemImage: AppState.Tab.assets.icon, value: .assets) {
                NavigationStack {
                    AssetListView()
                }
            }

            Tab(AppState.Tab.scan.title, systemImage: AppState.Tab.scan.icon, value: .scan) {
                NavigationStack {
                    ScannerView()
                }
            }

            Tab(AppState.Tab.settings.title, systemImage: AppState.Tab.settings.icon, value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(Color.ownlyPrimary)
    }
}
