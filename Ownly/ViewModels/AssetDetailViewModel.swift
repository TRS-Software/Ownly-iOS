import SwiftUI

@MainActor
final class AssetDetailViewModel: ObservableObject {
    @Published var asset: Asset
    @Published var devices: [Device] = []
    @Published var maintenance: [MaintenanceRecord] = []
    @Published var documents: [AssetDocument] = []
    @Published var media: [AssetMedia] = []
    @Published var timeline: [TimelineEntry] = []
    @Published var isLoading = false
    @Published var livePrice: LivePriceService.PriceData?
    @Published var showDeleteConfirmation = false

    private let deviceRepo = DeviceRepository.shared
    private let maintenanceRepo = MaintenanceRepository.shared
    private let documentRepo = DocumentRepository.shared
    private let mediaRepo = MediaRepository.shared
    private let timelineRepo = TimelineRepository.shared
    private let priceService = LivePriceService.shared
    private let assetRepo = AssetRepository.shared

    init(asset: Asset) {
        self.asset = asset
    }

    func loadAll() async {
        isLoading = true

        async let d: () = deviceRepo.fetchForAsset(asset.id)
        async let m: () = maintenanceRepo.fetchForAsset(asset.id)
        async let doc: () = documentRepo.fetchForAsset(asset.id)
        async let med: () = mediaRepo.fetchForAsset(asset.id)
        async let t: () = timelineRepo.fetchForAsset(asset.id)

        _ = await (d, m, doc, med, t)

        devices = deviceRepo.devicesForAsset(asset.id)
        maintenance = maintenanceRepo.recordsForAsset(asset.id)
        documents = documentRepo.documentsForAsset(asset.id)
        media = mediaRepo.mediaForAsset(asset.id)
        timeline = timelineRepo.entriesForAsset(asset.id)

        // Live price
        if asset.assetType.hasLivePrices {
            livePrice = try? await priceService.fetchPrice(for: asset)
        }

        isLoading = false
    }

    var effectiveValueCents: Int? {
        if let livePrice {
            let amount = asset.metadataDouble("amount") ?? asset.metadataDouble("shares") ?? 1.0
            return Int(livePrice.pricePerUnit * amount * 100)
        }
        return asset.displayValueCents
    }

    var totalMaintenanceCost: Int {
        maintenance.compactMap(\.costCents).reduce(0, +)
    }

    var beforeAfterPairs: [BeforeAfterPair] {
        mediaRepo.beforeAfterPairs(for: asset.id)
    }

    func deleteAsset() async -> Bool {
        do {
            try await assetRepo.delete(id: asset.id)
            return true
        } catch {
            return false
        }
    }

    func refresh() async {
        devices = deviceRepo.devicesForAsset(asset.id)
        maintenance = maintenanceRepo.recordsForAsset(asset.id)
        documents = documentRepo.documentsForAsset(asset.id)
        media = mediaRepo.mediaForAsset(asset.id)
        timeline = timelineRepo.entriesForAsset(asset.id)
    }
}
