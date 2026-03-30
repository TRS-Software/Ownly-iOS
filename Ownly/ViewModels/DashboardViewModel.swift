import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var portfolioValueCents: Int = 0
    @Published var portfolioChange24h: Double?
    @Published var assetCount: Int = 0
    @Published var topAssets: [Asset] = []
    @Published var recentActivity: [TimelineEntry] = []
    @Published var upcomingMaintenance: [MaintenanceRecord] = []
    @Published var livePrices: [UUID: LivePriceService.PriceData] = [:]

    private let assetRepo = AssetRepository.shared
    private let maintenanceRepo = MaintenanceRepository.shared
    private let timelineRepo = TimelineRepository.shared
    private let priceService = LivePriceService.shared

    func load() async {
        isLoading = true

        await assetRepo.fetchAll()
        let assets = assetRepo.assets
        assetCount = assets.count

        // Calculate portfolio value
        var totalCents = 0
        for asset in assets {
            totalCents += asset.displayValueCents ?? 0
        }
        portfolioValueCents = totalCents

        // Top 4 assets by value
        topAssets = Array(
            assets.sorted { ($0.displayValueCents ?? 0) > ($1.displayValueCents ?? 0) }
                .prefix(4)
        )

        // Recent activity
        recentActivity = timelineRepo.recentEntries(limit: 5)

        // Upcoming maintenance
        upcomingMaintenance = Array(maintenanceRepo.upcomingMaintenance().prefix(5))

        // Fetch live prices for crypto/stocks
        await fetchLivePrices(for: assets)

        isLoading = false
    }

    private func fetchLivePrices(for assets: [Asset]) async {
        let livePriceAssets = assets.filter { $0.assetType.hasLivePrices }

        await withTaskGroup(of: (UUID, LivePriceService.PriceData?).self) { group in
            for asset in livePriceAssets {
                group.addTask {
                    let price = try? await self.priceService.fetchPrice(for: asset)
                    return (asset.id, price)
                }
            }

            for await (id, price) in group {
                if let price {
                    livePrices[id] = price
                }
            }
        }

        // Recalculate portfolio with live prices
        var total = 0
        for asset in assets {
            if let livePrice = livePrices[asset.id] {
                let amount = asset.metadataDouble("amount") ?? asset.metadataDouble("shares") ?? 1.0
                total += Int(livePrice.pricePerUnit * amount * 100)
            } else {
                total += asset.displayValueCents ?? 0
            }
        }
        portfolioValueCents = total
    }

    func effectiveValue(for asset: Asset) -> Int? {
        if let livePrice = livePrices[asset.id] {
            let amount = asset.metadataDouble("amount") ?? asset.metadataDouble("shares") ?? 1.0
            return Int(livePrice.pricePerUnit * amount * 100)
        }
        return asset.displayValueCents
    }

    func priceChange(for asset: Asset) -> Double? {
        livePrices[asset.id]?.changePercent24h
    }
}
