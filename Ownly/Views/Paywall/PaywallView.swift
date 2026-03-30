import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var engagementStore: EngagementStore
    @Environment(\.dismiss) private var dismiss

    @State private var offerings: [Package] = []
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var error: String?
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.linearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text(String(localized: "paywall.title"))
                        .font(.title.bold())

                    Text(String(localized: "paywall.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "infinity", text: String(localized: "paywall.feature.unlimited_assets"))
                    FeatureRow(icon: "doc.text.viewfinder", text: String(localized: "paywall.feature.unlimited_ocr"))
                    FeatureRow(icon: "chart.pie.fill", text: String(localized: "paywall.feature.finance_tax"))
                    FeatureRow(icon: "square.and.arrow.up.fill", text: String(localized: "paywall.feature.export"))
                    FeatureRow(icon: "photo.stack.fill", text: String(localized: "paywall.feature.unlimited_photos"))
                    FeatureRow(icon: "bell.fill", text: String(localized: "paywall.feature.reminders"))
                    FeatureRow(icon: "icloud.fill", text: String(localized: "paywall.feature.cloud_sync"))
                }
                .padding(.horizontal, 24)

                // Pricing
                VStack(spacing: 12) {
                    PricingCard(
                        title: String(localized: "paywall.monthly"),
                        price: "€3,99",
                        period: String(localized: "paywall.per_month"),
                        isSelected: selectedPackage?.packageType == .monthly,
                        badge: nil
                    ) {
                        selectedPackage = offerings.first { $0.packageType == .monthly }
                    }

                    PricingCard(
                        title: String(localized: "paywall.annual"),
                        price: "€29,99",
                        period: String(localized: "paywall.per_year"),
                        isSelected: selectedPackage?.packageType == .annual,
                        badge: String(localized: "paywall.save_37")
                    ) {
                        selectedPackage = offerings.first { $0.packageType == .annual }
                    }

                    PricingCard(
                        title: String(localized: "paywall.lifetime"),
                        price: "€199,99",
                        period: String(localized: "paywall.one_time"),
                        isSelected: selectedPackage?.packageType == .lifetime,
                        badge: nil
                    ) {
                        selectedPackage = offerings.first { $0.packageType == .lifetime }
                    }
                }
                .padding(.horizontal, 24)

                // Purchase Button
                Button {
                    Task { await purchase() }
                } label: {
                    Group {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text(String(localized: "paywall.subscribe"))
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [Color.ownlyPrimary, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedPackage == nil || isPurchasing)
                .padding(.horizontal, 24)

                // Restore
                Button {
                    Task { await restore() }
                } label: {
                    if isRestoring {
                        ProgressView()
                    } else {
                        Text(String(localized: "paywall.restore"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Legal
                HStack(spacing: 16) {
                    Link(String(localized: "paywall.terms"), destination: URL(string: "https://ownly.app/terms")!)
                    Link(String(localized: "paywall.privacy"), destination: URL(string: "https://ownly.app/privacy")!)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .background(Color.ownlyBackground)
        .alert(String(localized: "error.title"), isPresented: $showError) {
            Button(String(localized: "ok")) {}
        } message: {
            Text(error ?? "")
        }
        .task { await loadOfferings() }
        .onAppear { engagementStore.trackPaywallShown() }
    }

    // MARK: - Actions

    private func loadOfferings() async {
        do {
            if let offering = try await RevenueCatService.shared.getCurrentOffering() {
                offerings = offering.availablePackages
                selectedPackage = offerings.first { $0.packageType == .annual }
                    ?? offerings.first
            }
        } catch {
            // Silently fail — show static prices
        }
    }

    private func purchase() async {
        guard let package = selectedPackage else { return }
        isPurchasing = true
        do {
            let info = try await RevenueCatService.shared.purchase(package: package)
            if info.entitlements[RevenueCatService.entitlementID]?.isActive == true {
                subscriptionStore.status = .premium
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        isPurchasing = false
    }

    private func restore() async {
        isRestoring = true
        do {
            let info = try await RevenueCatService.shared.restorePurchases()
            if info.entitlements[RevenueCatService.entitlementID]?.isActive == true {
                subscriptionStore.status = .premium
                dismiss()
            } else {
                self.error = String(localized: "paywall.no_purchases_found")
                showError = true
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        isRestoring = false
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.ownlyPrimary)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let title: String
    let price: String
    let period: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.subheadline.bold())
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(price)
                    .font(.title3.bold())
                    .foregroundStyle(isSelected ? Color.ownlyPrimary : Color.ownlyTextPrimary)
            }
            .padding(16)
            .background(isSelected ? Color.ownlyPrimary.opacity(0.08) : Color.ownlySecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.ownlyPrimary : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
