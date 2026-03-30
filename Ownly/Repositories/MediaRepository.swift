import Foundation
import UIKit

@MainActor
final class MediaRepository: ObservableObject {
    static let shared = MediaRepository()
    private let supabase = SupabaseService.shared

    @Published var media: [UUID: [AssetMedia]] = [:]
    @Published var isLoading = false

    private init() {}

    func fetchForAsset(_ assetId: UUID) async {
        isLoading = true
        do {
            let result: [AssetMedia] = try await supabase.fetch(
                from: "media",
                filters: [("asset_id", assetId.uuidString)],
                orderBy: "taken_at",
                ascending: false
            )
            media[assetId] = result
        } catch {
            print("MediaRepository error: \(error)")
        }
        isLoading = false
    }

    func create(_ mediaItem: AssetMedia) async throws {
        try await supabase.insert(into: "media", value: mediaItem)
        media[mediaItem.assetId, default: []].insert(mediaItem, at: 0)
    }

    func delete(id: UUID, assetId: UUID) async throws {
        try await supabase.delete(from: "media", id: id)
        media[assetId]?.removeAll { $0.id == id }
    }

    func mediaForAsset(_ assetId: UUID) -> [AssetMedia] {
        media[assetId] ?? []
    }

    func beforeAfterPairs(for assetId: UUID) -> [BeforeAfterPair] {
        let allMedia = mediaForAsset(assetId)
        var pairs: [BeforeAfterPair] = []
        var usedIds: Set<UUID> = []

        for item in allMedia where item.pairId != nil && !usedIds.contains(item.id) {
            guard let pairId = item.pairId else { continue }
            if let partner = allMedia.first(where: { $0.pairId == pairId && $0.id != item.id }) {
                let before = item.type == .before ? item : partner
                let after = item.type == .after ? item : partner
                pairs.append(BeforeAfterPair(id: pairId, before: before, after: after))
                usedIds.insert(item.id)
                usedIds.insert(partner.id)
            }
        }

        return pairs
    }

    // MARK: - Upload

    func uploadPhoto(
        image: UIImage,
        assetId: UUID,
        userId: UUID,
        type: MediaType = .photo,
        caption: String? = nil,
        pairId: UUID? = nil,
        deviceId: UUID? = nil,
        maintenanceId: UUID? = nil
    ) async throws -> AssetMedia {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw MediaError.compressionFailed
        }

        let fileName = "\(UUID().uuidString).jpg"
        let path = "\(userId.uuidString)/\(assetId.uuidString)/\(fileName)"

        let url = try await supabase.uploadFile(
            bucket: "asset-photos",
            path: path,
            data: data
        )

        let mediaItem = AssetMedia(
            id: UUID(),
            assetId: assetId,
            deviceId: deviceId,
            maintenanceId: maintenanceId,
            userId: userId,
            type: type,
            url: url,
            thumbnailUrl: url,
            caption: caption,
            takenAt: Date(),
            pairId: pairId,
            linkedCostCents: nil,
            metadata: [:],
            createdAt: Date()
        )

        try await create(mediaItem)
        return mediaItem
    }
}

enum MediaError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        "Failed to compress image"
    }
}
