import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var appState: AppState
    @StateObject private var authViewModel = AuthViewModel()

    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var showingPaywall = false
    @State private var cachedDataSize: String = "..."
    @State private var showingPrivacyPolicy = false

    var body: some View {
        List {
            appearanceSection
            localizationSection
            notificationsSection
            subscriptionSection
            storageSection
            dataSection
            aboutSection
            signOutSection
        }
        .listStyle(.insetGrouped)
        .background(Color.ownlyBackground)
        .navigationTitle(String(localized: "settings.title"))
        .sheet(isPresented: $showingPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
        .confirmationDialog(
            String(localized: "settings.delete_account_confirm"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.delete_account"), role: .destructive) {
                Task {
                    await authViewModel.signOut()
                }
            }
        } message: {
            Text(String(localized: "settings.delete_account_message"))
        }
        .confirmationDialog(
            String(localized: "settings.sign_out_confirm"),
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.sign_out"), role: .destructive) {
                Task {
                    await authViewModel.signOut()
                }
            }
        }
        .task {
            cachedDataSize = calculateCacheSize()
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Picker(selection: $settingsStore.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.displayName, systemImage: theme.icon)
                        .tag(theme)
                }
            } label: {
                Label(String(localized: "settings.theme"), systemImage: "paintbrush.fill")
            }
        } header: {
            Text(String(localized: "settings.appearance"))
        }
    }

    // MARK: - Localization

    private var localizationSection: some View {
        Section {
            // Language
            Picker(selection: $settingsStore.locale) {
                ForEach(SupportedLocale.all) { locale in
                    HStack(spacing: 8) {
                        Text(locale.flag)
                        Text(locale.name)
                    }
                    .tag(locale.code)
                }
            } label: {
                Label(String(localized: "settings.language"), systemImage: "globe")
            }

            // Currency
            Picker(selection: $settingsStore.currency) {
                ForEach(SupportedCurrency.all) { currency in
                    HStack(spacing: 8) {
                        Text(currency.symbol)
                            .frame(width: 30, alignment: .leading)
                        Text("\(currency.code) - \(currency.name)")
                    }
                    .tag(currency.code)
                }
            } label: {
                Label(String(localized: "settings.currency"), systemImage: "banknote.fill")
            }
        } header: {
            Text(String(localized: "settings.localization"))
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $settingsStore.remindersEnabled) {
                Label(String(localized: "settings.maintenance_reminders"), systemImage: "bell.fill")
            }
            .tint(Color.ownlyPrimary)

            Toggle(isOn: $settingsStore.cloudSyncEnabled) {
                Label(String(localized: "settings.cloud_sync"), systemImage: "icloud.fill")
            }
            .tint(Color.ownlyPrimary)
        } header: {
            Text(String(localized: "settings.sync_notifications"))
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        Section {
            HStack {
                Label(String(localized: "settings.current_plan"), systemImage: "star.fill")

                Spacer()

                Text(subscriptionStatusText)
                    .font(.subheadline.bold())
                    .foregroundStyle(subscriptionStore.isPremium ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (subscriptionStore.isPremium ? Color.green : Color.secondary)
                            .opacity(0.12)
                    )
                    .clipShape(Capsule())
            }

            if subscriptionStore.status == .trial {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                    Text(String(localized: "settings.trial_remaining \(subscriptionStore.trialDaysRemaining)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                showingPaywall = true
            } label: {
                Label(
                    subscriptionStore.isPremium
                        ? String(localized: "settings.manage_subscription")
                        : String(localized: "settings.upgrade_premium"),
                    systemImage: subscriptionStore.isPremium ? "gearshape.fill" : "crown.fill"
                )
            }
        } header: {
            Text(String(localized: "settings.subscription"))
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section {
            HStack {
                Label(String(localized: "settings.cached_data"), systemImage: "internaldrive.fill")
                Spacer()
                Text(cachedDataSize)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "settings.storage"))
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            Button {
                // Export all data action
            } label: {
                Label(String(localized: "settings.export_all_data"), systemImage: "square.and.arrow.up.fill")
            }

            Button {
                showingPrivacyPolicy = true
            } label: {
                Label(String(localized: "settings.privacy_policy"), systemImage: "hand.raised.fill")
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                NavigationStack {
                    PrivacyPolicyWebView()
                        .navigationTitle(String(localized: "settings.privacy_policy"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(String(localized: "done")) {
                                    showingPrivacyPolicy = false
                                }
                            }
                        }
                }
            }

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label(String(localized: "settings.delete_account"), systemImage: "trash.fill")
            }
        } header: {
            Text(String(localized: "settings.data"))
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Label(String(localized: "settings.version"), systemImage: "info.circle.fill")
                Spacer()
                Text(appVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Ownly")
                        .font(.headline)
                        .foregroundStyle(Color.ownlyPrimary)
                    Text(String(localized: "settings.tagline"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        } header: {
            Text(String(localized: "settings.about"))
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label(String(localized: "settings.sign_out"), systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private var subscriptionStatusText: String {
        switch subscriptionStore.status {
        case .free: return String(localized: "settings.plan_free")
        case .trial: return String(localized: "settings.plan_trial")
        case .premium: return String(localized: "settings.plan_premium")
        case .expiredTrial: return String(localized: "settings.plan_expired")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func calculateCacheSize() -> String {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let cacheURL else { return "0 MB" }

        var totalSize: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: cacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

// MARK: - Privacy Policy Web View

private struct PrivacyPolicyWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebViewWrapper {
        let webView = WKWebViewWrapper()
        if let url = URL(string: "https://ownly.app/privacy") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebViewWrapper, context: Context) {}
}

import WebKit

private class WKWebViewWrapper: WKWebView {}
