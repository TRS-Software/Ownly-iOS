import SwiftUI

struct AssetDetailView: View {
    @StateObject private var viewModel: AssetDetailViewModel
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false

    init(asset: Asset) {
        _viewModel = StateObject(wrappedValue: AssetDetailViewModel(asset: asset))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero / Cover
                coverSection

                // Value Cards
                valueCardsSection
                    .padding()

                // Tab Navigation
                tabSection
            }
        }
        .background(Color.ownlyBackground)
        .navigationTitle(viewModel.asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label(String(localized: "edit"), systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        viewModel.showDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                AssetFormView(editing: viewModel.asset)
            }
        }
        .confirmationDialog(
            String(localized: "asset.delete_confirm"),
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete"), role: .destructive) {
                Task {
                    if await viewModel.deleteAsset() {
                        dismiss()
                    }
                }
            }
        }
        .onFirstAppear {
            await viewModel.loadAll()
        }
    }

    // MARK: - Cover

    private var coverSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageUrl = viewModel.asset.coverImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        iconPlaceholder
                    }
                }
            } else {
                iconPlaceholder
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var iconPlaceholder: some View {
        ZStack {
            viewModel.asset.assetType.color.opacity(0.15)
            VStack(spacing: 8) {
                Image(systemName: viewModel.asset.assetType.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(viewModel.asset.assetType.color)
                Text(viewModel.asset.assetType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Value Cards

    private var valueCardsSection: some View {
        HStack(spacing: 12) {
            if let value = viewModel.effectiveValueCents {
                ValueCard(
                    title: String(localized: "asset.current_value"),
                    value: value.formattedCurrency(code: viewModel.asset.currency),
                    color: .ownlyPrimary
                )
            }

            if let purchase = viewModel.asset.purchasePriceCents {
                ValueCard(
                    title: String(localized: "asset.purchase_price"),
                    value: purchase.formattedCurrency(code: viewModel.asset.currency),
                    color: .secondary
                )
            }

            if let livePrice = viewModel.livePrice {
                ValueCard(
                    title: String(localized: "asset.live_price"),
                    value: String(format: "%.2f %@", livePrice.pricePerUnit, livePrice.currency),
                    change: livePrice.changePercent24h,
                    color: .green
                )
            }
        }
    }

    // MARK: - Tabs

    private var tabSection: some View {
        VStack(spacing: 0) {
            // Devices
            DetailSectionLink(
                icon: "cpu.fill",
                title: String(localized: "tab.devices"),
                count: viewModel.devices.count
            ) {
                DeviceListView(assetId: viewModel.asset.id, assetType: viewModel.asset.assetType)
            }

            // Maintenance
            DetailSectionLink(
                icon: "wrench.fill",
                title: String(localized: "tab.maintenance"),
                count: viewModel.maintenance.count,
                subtitle: viewModel.totalMaintenanceCost > 0
                    ? viewModel.totalMaintenanceCost.formattedCurrency(code: viewModel.asset.currency)
                    : nil
            ) {
                MaintenanceListView(assetId: viewModel.asset.id, currency: viewModel.asset.currency)
            }

            // Documents
            DetailSectionLink(
                icon: "doc.fill",
                title: String(localized: "tab.documents"),
                count: viewModel.documents.count
            ) {
                DocumentListView(assetId: viewModel.asset.id)
            }

            // Photos
            DetailSectionLink(
                icon: "photo.fill",
                title: String(localized: "tab.photos"),
                count: viewModel.media.count
            ) {
                MediaGalleryView(assetId: viewModel.asset.id, userId: viewModel.asset.userId)
            }

            // Finance (Premium)
            DetailSectionLink(
                icon: "chart.pie.fill",
                title: String(localized: "tab.finances"),
                isPremium: !subscriptionStore.canAccessFinance()
            ) {
                FinanceView(asset: viewModel.asset)
            }

            // Tax (Premium, Property only)
            if viewModel.asset.assetType.isProperty {
                DetailSectionLink(
                    icon: "percent",
                    title: String(localized: "tab.tax"),
                    isPremium: !subscriptionStore.canAccessTax()
                ) {
                    TaxView(asset: viewModel.asset)
                }
            }

            // Timeline
            DetailSectionLink(
                icon: "clock.fill",
                title: String(localized: "tab.timeline"),
                count: viewModel.timeline.count
            ) {
                TimelineView(assetId: viewModel.asset.id)
            }

            // Export (Premium)
            DetailSectionLink(
                icon: "square.and.arrow.up.fill",
                title: String(localized: "tab.export"),
                isPremium: !subscriptionStore.canExport()
            ) {
                ExportView(asset: viewModel.asset)
            }
        }
        .padding()
    }
}

// MARK: - Value Card

struct ValueCard: View {
    let title: String
    let value: String
    var change: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(change.formattedPercent())
                }
                .font(.caption2.bold())
                .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ownlyCard()
    }
}

// MARK: - Section Link

struct DetailSectionLink<Destination: View>: View {
    let icon: String
    let title: String
    var count: Int?
    var subtitle: String?
    var isPremium: Bool = false
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            if isPremium {
                PaywallView()
            } else {
                destination()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.ownlyPrimary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(Color.ownlyTextPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let count {
                    Text("\(count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.ownlyFill)
                        .clipShape(Capsule())
                }

                if isPremium {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
