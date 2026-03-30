import Foundation

struct Asset: Codable, Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var assetType: AssetType
    var name: String
    var description: String?
    var metadata: [String: AnyCodable]
    var coverImageUrl: String?
    var estimatedValueCents: Int?
    var purchasePriceCents: Int?
    var purchaseDate: Date?
    var currency: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        assetType: AssetType,
        name: String,
        description: String? = nil,
        metadata: [String: AnyCodable] = [:],
        coverImageUrl: String? = nil,
        estimatedValueCents: Int? = nil,
        purchasePriceCents: Int? = nil,
        purchaseDate: Date? = nil,
        currency: String = "EUR",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.assetType = assetType
        self.name = name
        self.description = description
        self.metadata = metadata
        self.coverImageUrl = coverImageUrl
        self.estimatedValueCents = estimatedValueCents
        self.purchasePriceCents = purchasePriceCents
        self.purchaseDate = purchaseDate
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case assetType = "asset_type"
        case name, description, metadata
        case coverImageUrl = "cover_image_url"
        case estimatedValueCents = "estimated_value_cents"
        case purchasePriceCents = "purchase_price_cents"
        case purchaseDate = "purchase_date"
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Metadata Helpers

    func metadataString(_ key: String) -> String? {
        metadata[key]?.stringValue
    }

    func metadataInt(_ key: String) -> Int? {
        metadata[key]?.intValue
    }

    func metadataDouble(_ key: String) -> Double? {
        metadata[key]?.doubleValue
    }

    /// Effective display value: estimated or purchase price
    var displayValueCents: Int? {
        estimatedValueCents ?? purchasePriceCents
    }

    /// Address string for property types
    var addressString: String? {
        guard assetType.isProperty else { return nil }
        let parts = [metadataString("address"), metadataString("zip"), metadataString("city")]
        let nonNil = parts.compactMap { $0 }.filter { !$0.isEmpty }
        return nonNil.isEmpty ? nil : nonNil.joined(separator: ", ")
    }

    /// Subtitle for list display
    var subtitle: String? {
        switch assetType {
        case .house, .apartment, .land, .commercial:
            return addressString
        case .car, .motorcycle:
            let brand = metadataString("brand") ?? ""
            let model = metadataString("model") ?? ""
            return [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        case .watch, .jewelry:
            return metadataString("brand")
        case .electronics:
            let brand = metadataString("brand") ?? ""
            let model = metadataString("model") ?? ""
            return [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        case .stocks:
            return metadataString("ticker")
        case .crypto:
            return metadataString("symbol")?.uppercased()
        case .art:
            return metadataString("artist")
        default:
            return nil
        }
    }

    static func == (lhs: Asset, rhs: Asset) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tenant & Rental

struct TenantInfo: Codable, Identifiable {
    let id: UUID
    var name: String
    var contact: String?
    var unitName: String?
    var monthlyRentCents: Int?
    var isActive: Bool
    var leaseStartDate: Date?
    var leaseEndDate: Date?
    var documents: [String]?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, contact
        case unitName = "unit_name"
        case monthlyRentCents = "monthly_rent_cents"
        case isActive = "is_active"
        case leaseStartDate = "lease_start_date"
        case leaseEndDate = "lease_end_date"
        case documents, notes
    }
}

struct RentalMetadata: Codable {
    var isRented: Bool
    var tenants: [TenantInfo]
    var totalMonthlyRentCents: Int?

    enum CodingKeys: String, CodingKey {
        case isRented = "is_rented"
        case tenants
        case totalMonthlyRentCents = "total_monthly_rent_cents"
    }
}
