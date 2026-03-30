import Foundation
import UIKit

@MainActor
final class MediaRepository: ObservableObject {
    static let shared = MediaRepository()
    private let supabase = SupabaseService.shared

    @Published var media: [UUID: [AssetMedia]] = [:]
    @Published var isLoading = false
    @Published var error: String?

    /// Maximum upload size for images: 10 MB
    private static let maxImageBytes = 10 * 1024 * 1024

    /// JPEG magic bytes prefix
    private static let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF]
    /// PNG magic bytes prefix
    private static let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    /// WebP magic bytes (at offset 8): "WEBP"
    private static let webpMagic: [UInt8] = [0x57, 0x45, 0x42, 0x50]

    private init() {}

    // MARK: - Image Validation

    /// Validates that the provided data is actually a recognized image format and within size limits.
    private func validateImageData(_ data: Data) throws {
        guard data.count <= Self.maxImageBytes else {
            throw SupabaseSecurityError.fileTooLarge(data.count)
        }

        let bytes = [UInt8](data.prefix(12))
        let isJPEG = bytes.starts(with: Self.jpegMagic)
        let isPNG = bytes.starts(with: Self.pngMagic)
        let isWebP = bytes.count >= 12 && Array(bytes[8..<12]) == Self.webpMagic

        guard isJPEG || isPNG || isWebP else {
            throw MediaError.invalidImageData
        }
    }

    // MARK: - Fetch

    func fetchForAsset(_ assetId: UUID) async {
        isLoading = true
        error = nil
        do {
            let userId = try await supabase.requireUserId()
            let result: [AssetMedia] = try await supabase.fetch(
                from: "media",
                filters: [
                    ("asset_id", assetId.uuidString),
                    ("user_id", userId.uuidString),
                ],
                orderBy: "taken_at",
                ascending: false
            )
            media[assetId] = result
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(_ mediaItem: AssetMedia) async throws {
        try await supabase.insert(into: "media", value: mediaItem)
        media[mediaItem.assetId, default: []].insert(mediaItem, at: 0)
    }

    func delete(id: UUID, assetId: UUID) async throws {
        let userId = try await supabase.requireUserId()
        if let cached = media[assetId]?.first(where: { $0.id == id }) {
            guard cached.userId == userId else {
                self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
                throw SupabaseSecurityError.ownershipMismatch
            }
        } else {
            let item: AssetMedia = try await supabase.fetchSingle(from: "media", id: id)
            guard item.userId == userId else {
                self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
                throw SupabaseSecurityError.ownershipMismatch
            }
        }
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
        // Ensure the caller is authenticated and matches the provided userId
        let authenticatedUserId = try await supabase.requireUserId()
        guard authenticatedUserId == userId else {
            throw SupabaseSecurityError.ownershipMismatch
        }

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw MediaError.compressionFailed
        }

        // Validate image data: check magic bytes and size
        try validateImageData(data)

        let fileName = "\(UUID().uuidString).jpg"
        let path = "\(userId.uuidString)/\(assetId.uuidString)/\(fileName)"

        let url = try await supabase.uploadFile(
            bucket: "asset-photos",
            path: path,
            data: data,
            contentType: "image/jpeg"
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
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image."
        case .invalidImageData:
            return "The provided data is not a valid image (expected JPEG, PNG, or WebP)."
        }
    }
}
