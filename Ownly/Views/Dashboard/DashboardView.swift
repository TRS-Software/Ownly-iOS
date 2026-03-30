import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Portfolio Summary
                PortfolioSummaryCard(
                    valueCents: viewModel.portfolioValueCents,
                    assetCount: viewModel.assetCount,
                    currency: settingsStore.currency,
                    change24h: viewModel.portfolioChange24h
                )
                .padding(.horizontal)

                // Trial Banner
                if subscriptionStore.status == .trial {
                    TrialBannerView(daysRemaining: subscriptionStore.trialDaysRemaining)
                        .padding(.horizontal)
                }

                // Quick Actions
                QuickActionsView()
                    .padding(.horizontal)

                // Top Assets
                if !viewModel.topAssets.isEmpty {
                    SectionHeader(title: String(localized: "dashboard.top_assets"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.topAssets) { asset in
                                NavigationLink(value: asset) {
                                    MiniAssetCard(
                                        asset: asset,
                                        effectiveValue: viewModel.effectiveValue(for: asset),
                                        priceChange: viewModel.priceChange(for: asset),
                                        currency: settingsStore.currency
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Upcoming Maintenance
                if !viewModel.upcomingMaintenance.isEmpty {
                    SectionHeader(title: String(localized: "dashboard.upcoming_maintenance"))
                    ForEach(viewModel.upcomingMaintenance) { record in
                        UpcomingMaintenanceRow(record: record, currency: settingsStore.currency)
                    }
                    .padding(.horizontal)
                }

                // Recent Activity
                if !viewModel.recentActivity.isEmpty {
                    SectionHeader(title: String(localized: "dashboard.recent_activity"))
                    ForEach(viewModel.recentActivity) { entry in
                        RecentActivityRow(entry: entry)
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 100)
            }
            .padding(.top)
        }
        .background(Color.ownlyBackground)
        .navigationTitle(String(localized: "dashboard.title"))
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset)
        }
        .refreshable {
            await viewModel.load()
        }
        .onFirstAppear {
            await viewModel.load()
        }
    }
}

// MARK: - Subviews

struct PortfolioSummaryCard: View {
    let valueCents: Int
    let assetCount: Int
    let currency: String
    let change24h: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "dashboard.portfolio_value"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(valueCents.formattedCurrency(code: currency))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ownlyTextPrimary)

            HStack(spacing: 16) {
                Label("\(assetCount) \(String(localized: "dashboard.assets"))",
                      systemImage: "cube.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let change = change24h {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(change.formattedPercent())
                    }
                    .font(.caption.bold())
                    .foregroundStyle(change >= 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((change >= 0 ? Color.green : Color.red).opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ownlyCard()
    }
}

struct QuickActionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                icon: "plus.circle.fill",
                title: String(localized: "action.new_asset"),
                color: .blue
            ) {
                // Navigate to new asset
            }

            QuickActionButton(
                icon: "doc.text.viewfinder",
                title: String(localized: "action.scan"),
                color: .purple
            ) {
                appState.selectedTab = .scan
            }

            QuickActionButton(
                icon: "chart.pie.fill",
                title: String(localized: "action.portfolio"),
                color: .green
            ) {
                appState.selectedTab = .assets
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Color.ownlyTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.ownlySecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct MiniAssetCard: View {
    let asset: Asset
    let effectiveValue: Int?
    let priceChange: Double?
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: asset.assetType.icon)
                    .font(.title3)
                    .foregroundStyle(asset.assetType.color)

                Spacer()

                if let change = priceChange {
                    Text(change >= 0 ? "+\(change.formattedPercent())" : change.formattedPercent())
                        .font(.caption2.bold())
                        .foregroundStyle(change >= 0 ? .green : .red)
                }
            }

            Text(asset.name)
                .font(.subheadline.bold())
                .lineLimit(1)

            if let subtitle = asset.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let value = effectiveValue {
                Text(value.formattedCurrency(code: currency))
                    .font(.footnote.bold())
                    .foregroundStyle(Color.ownlyPrimary)
            }
        }
        .frame(width: 160)
        .ownlyCard()
    }
}

struct UpcomingMaintenanceRow: View {
    let record: MaintenanceRecord
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.type.icon)
                .font(.title3)
                .foregroundStyle(record.type.color)
                .frame(width: 36, height: 36)
                .background(record.type.color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                if let dueDate = record.nextDueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(record.isDueSoon ? .orange : .secondary)
                }
            }

            Spacer()

            if let cost = record.costCents {
                Text(cost.formattedCurrency(code: currency))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .ownlyCard()
    }
}

struct RecentActivityRow: View {
    let entry: TimelineEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.entryType.icon)
                .font(.body)
                .foregroundStyle(entry.entryType.color)
                .frame(width: 32, height: 32)
                .background(entry.entryType.color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(entry.occurredAt.relativeFormatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
}

struct TrialBannerView: View {
    let daysRemaining: Int

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text(String(localized: "trial.days_remaining \(daysRemaining)"))
                .font(.subheadline.bold())
            Spacer()
            NavigationLink(String(localized: "trial.upgrade")) {
                PaywallView()
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.ownlyPrimary)
            .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.ownlyPrimary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
