import SwiftUI

struct AssetListView: View {
    @StateObject private var viewModel = AssetListViewModel()
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var showingNewAsset = false
    @State private var showingPaywall = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: String(localized: "filter.all"),
                        isSelected: viewModel.selectedType == nil
                    ) {
                        viewModel.selectedType = nil
                    }

                    ForEach(AssetType.allCases) { type in
                        FilterChip(
                            title: type.displayName,
                            icon: type.icon,
                            isSelected: viewModel.selectedType == type
                        ) {
                            viewModel.selectedType = viewModel.selectedType == type ? nil : type
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if viewModel.isEmpty {
                EmptyAssetView {
                    showingNewAsset = true
                }
            } else {
                ScrollView {
                    if viewModel.viewMode == .grid {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(viewModel.filteredAssets) { asset in
                                NavigationLink(value: asset) {
                                    AssetGridCard(asset: asset, currency: settingsStore.currency)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.filteredAssets) { asset in
                                NavigationLink(value: asset) {
                                    AssetListRow(asset: asset, currency: settingsStore.currency)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        .background(Color.ownlyBackground)
        .searchable(text: $viewModel.searchText, prompt: String(localized: "search.assets"))
        .navigationTitle(String(localized: "assets.title"))
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(AssetSortOption.allCases) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            Label(option.displayName, systemImage: viewModel.sortOption == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation {
                            viewModel.viewMode = viewModel.viewMode == .grid ? .list : .grid
                        }
                    } label: {
                        Image(systemName: viewModel.viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                    }

                    Button {
                        if subscriptionStore.canCreateAsset(currentCount: viewModel.filteredAssets.count) {
                            showingNewAsset = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewAsset) {
            NavigationStack {
                AssetFormView()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .refreshable {
            await viewModel.load()
        }
        .onFirstAppear {
            await viewModel.load()
        }
    }
}

// MARK: - Grid Card

struct AssetGridCard: View {
    let asset: Asset
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cover image or icon
            ZStack {
                if let imageUrl = asset.coverImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            assetIconView
                        }
                    }
                } else {
                    assetIconView
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(asset.assetType.displayName)
                        .font(.caption2)
                        .foregroundStyle(asset.assetType.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(asset.assetType.color.opacity(0.12))
                        .clipShape(Capsule())
                    Spacer()
                }

                Text(asset.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundStyle(Color.ownlyTextPrimary)

                if let subtitle = asset.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let value = asset.displayValueCents {
                    Text(value.formattedCurrency(code: asset.currency))
                        .font(.footnote.bold())
                        .foregroundStyle(Color.ownlyPrimary)
                }
            }
        }
        .ownlyCard()
    }

    private var assetIconView: some View {
        ZStack {
            asset.assetType.color.opacity(0.15)
            Image(systemName: asset.assetType.icon)
                .font(.largeTitle)
                .foregroundStyle(asset.assetType.color)
        }
    }
}

// MARK: - List Row

struct AssetListRow: View {
    let asset: Asset
    let currency: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                asset.assetType.color.opacity(0.15)
                Image(systemName: asset.assetType.icon)
                    .font(.title3)
                    .foregroundStyle(asset.assetType.color)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyTextPrimary)
                if let subtitle = asset.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let value = asset.displayValueCents {
                Text(value.formattedCurrency(code: asset.currency))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ownlyPrimary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.ownlySecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.ownlyPrimary : Color.ownlySecondaryBackground)
            .foregroundStyle(isSelected ? .white : Color.ownlyTextPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyAssetView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text(String(localized: "assets.empty.title"))
                .font(.title3.bold())

            Text(String(localized: "assets.empty.description"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                action()
            } label: {
                Label(String(localized: "assets.empty.add_first"), systemImage: "plus.circle.fill")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.ownlyPrimary)
        }
        .frame(maxHeight: .infinity)
    }
}
