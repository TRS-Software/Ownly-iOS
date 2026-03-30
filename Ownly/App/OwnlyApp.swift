import SwiftUI
import RevenueCat

@main
struct OwnlyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var subscriptionStore = SubscriptionStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var onboardingStore = OnboardingStore()
    @StateObject private var engagementStore = EngagementStore()

    init() {
        configureRevenueCat()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(subscriptionStore)
                .environmentObject(settingsStore)
                .environmentObject(onboardingStore)
                .environmentObject(engagementStore)
                .preferredColorScheme(settingsStore.resolvedColorScheme)
                .task {
                    await authViewModel.observeAuthState()
                    engagementStore.incrementSessions()
                }
        }
    }

    private func configureRevenueCat() {
        Purchases.logLevel = .debug
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String,
           !apiKey.isEmpty {
            Purchases.configure(withAPIKey: apiKey)
        }
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
