import Foundation
import SwiftUI

struct AssetMedia: Codable, Identifiable, Hashable {
    let id: UUID
    var assetId: UUID
    var deviceId: UUID?
    var maintenanceId: UUID?
    var userId: UUID
    var type: MediaType
    var url: String
    var thumbnailUrl: String?
    var caption: String?
    var takenAt: Date
    var pairId: UUID?
    var linkedCostCents: Int?
    var metadata: [String: AnyCodable]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case assetId = "asset_id"
        case deviceId = "device_id"
        case maintenanceId = "maintenance_id"
        case userId = "user_id"
        case type, url
        case thumbnailUrl = "thumbnail_url"
        case caption
        case takenAt = "taken_at"
        case pairId = "pair_id"
        case linkedCostCents = "linked_cost_cents"
        case metadata
        case createdAt = "created_at"
    }

    static func == (lhs: AssetMedia, rhs: AssetMedia) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case photo
    case before
    case after
    case damage
    case nameplate

    var id: String { rawValue }

    var displayName: String {
        NSLocalizedString("media_type.\(rawValue)", comment: "")
    }

    var icon: String {
        switch self {
        case .photo: return "photo.fill"
        case .before: return "arrow.left.circle.fill"
        case .after: return "arrow.right.circle.fill"
        case .damage: return "exclamationmark.triangle.fill"
        case .nameplate: return "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .photo: return .blue
        case .before: return .orange
        case .after: return .green
        case .damage: return .red
        case .nameplate: return .purple
        }
    }
}

/// Paired before/after photos
struct BeforeAfterPair: Identifiable {
    let id: UUID
    let before: AssetMedia
    let after: AssetMedia
    var linkedCostCents: Int? { after.linkedCostCents ?? before.linkedCostCents }
}
