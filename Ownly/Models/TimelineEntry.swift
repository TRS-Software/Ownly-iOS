import Foundation
import SwiftUI

struct TimelineEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var assetId: UUID
    var userId: UUID
    var entryType: TimelineEntryType
    var title: String
    var description: String?
    var occurredAt: Date
    var referenceId: UUID?
    var referenceType: String?
    var metadata: [String: AnyCodable]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case assetId = "asset_id"
        case userId = "user_id"
        case entryType = "entry_type"
        case title, description
        case occurredAt = "occurred_at"
        case referenceId = "reference_id"
        case referenceType = "reference_type"
        case metadata
        case createdAt = "created_at"
    }

    static func == (lhs: TimelineEntry, rhs: TimelineEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum TimelineEntryType: String, Codable, CaseIterable {
    case assetCreated = "asset_created"
    case deviceAdded = "device_added"
    case deviceReplaced = "device_replaced"
    case maintenance
    case repair
    case inspection
    case documentAdded = "document_added"
    case photoAdded = "photo_added"
    case beforeAfter = "before_after"
    case note
    case reminder

    var icon: String {
        switch self {
        case .assetCreated: return "plus.circle.fill"
        case .deviceAdded: return "cpu.fill"
        case .deviceReplaced: return "arrow.triangle.2.circlepath"
        case .maintenance: return "wrench.fill"
        case .repair: return "hammer.fill"
        case .inspection: return "magnifyingglass"
        case .documentAdded: return "doc.fill"
        case .photoAdded: return "photo.fill"
        case .beforeAfter: return "arrow.left.arrow.right"
        case .note: return "note.text"
        case .reminder: return "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .assetCreated: return .green
        case .deviceAdded, .deviceReplaced: return .purple
        case .maintenance: return .blue
        case .repair: return .orange
        case .inspection: return .indigo
        case .documentAdded: return .teal
        case .photoAdded: return .pink
        case .beforeAfter: return .cyan
        case .note: return .gray
        case .reminder: return .yellow
        }
    }
}
