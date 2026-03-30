import SwiftUI

@MainActor
final class AssetFormViewModel: ObservableObject {
    @Published var assetType: AssetType?
    @Published var name = ""
    @Published var description = ""
    @Published var metadata: [String: String] = [:]
    @Published var estimatedValueCents: Int?
    @Published var purchasePriceCents: Int?
    @Published var purchaseDate = Date()
    @Published var currency = "EUR"
    @Published var coverImage: UIImage?
    @Published var isSubmitting = false
    @Published var error: String?
    @Published var step: FormStep = .selectType

    enum FormStep {
        case selectType
        case fillDetails
    }

    private let assetRepo = AssetRepository.shared
    private let mediaRepo = MediaRepository.shared
    var editingAsset: Asset?

    init(editing asset: Asset? = nil) {
        if let asset {
            self.editingAsset = asset
            self.assetType = asset.assetType
            self.name = asset.name
            self.description = asset.description ?? ""
            self.estimatedValueCents = asset.estimatedValueCents
            self.purchasePriceCents = asset.purchasePriceCents
            self.purchaseDate = asset.purchaseDate ?? Date()
            self.currency = asset.currency
            self.step = .fillDetails

            // Map metadata
            for (key, value) in asset.metadata {
                metadata[key] = value.stringValue ?? ""
            }
        }
    }

    func selectType(_ type: AssetType) {
        assetType = type
        withAnimation { step = .fillDetails }
    }

    var isValid: Bool {
        guard let type = assetType else { return false }
        let requiredFields = type.formFields.filter(\.isRequired)
        for field in requiredFields {
            let value = metadata[field.key] ?? ""
            if value.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func submit(userId: UUID) async -> Asset? {
        guard isValid, let assetType else { return nil }

        isSubmitting = true
        error = nil

        let metadataCodable = metadata.filter { !$0.value.isEmpty }
            .mapValues { AnyCodable($0) }

        do {
            if var existing = editingAsset {
                // Update
                existing.name = name
                existing.description = description.isEmpty ? nil : description
                existing.assetType = assetType
                existing.metadata = metadataCodable
                existing.estimatedValueCents = estimatedValueCents
                existing.purchasePriceCents = purchasePriceCents
                existing.purchaseDate = purchaseDate
                existing.currency = currency
                existing.updatedAt = Date()

                try await assetRepo.update(existing)
                isSubmitting = false
                return existing
            } else {
                // Create
                let asset = Asset(
                    userId: userId,
                    assetType: assetType,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    metadata: metadataCodable,
                    estimatedValueCents: estimatedValueCents,
                    purchasePriceCents: purchasePriceCents,
                    purchaseDate: purchaseDate,
                    currency: currency
                )

                try await assetRepo.create(asset)

                // Upload cover image if provided
                if let image = coverImage {
                    let media = try await mediaRepo.uploadPhoto(
                        image: image,
                        assetId: asset.id,
                        userId: userId,
                        type: .photo,
                        caption: "Cover"
                    )
                    var updated = asset
                    updated.coverImageUrl = media.url
                    try await assetRepo.update(updated)
                }

                isSubmitting = false
                return asset
            }
        } catch {
            self.error = error.localizedDescription
            isSubmitting = false
            return nil
        }
    }
}
