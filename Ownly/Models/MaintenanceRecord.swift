import Foundation
import SwiftUI

struct MaintenanceRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var assetId: UUID
    var deviceId: UUID?
    var userId: UUID
    var type: MaintenanceType
    var title: String
    var description: String?
    var performedBy: String?
    var performedAt: Date
    var nextDueDate: Date?
    var costCents: Int?
    var currency: String
    var invoiceDocumentId: UUID?
    var metadata: [String: AnyCodable]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case assetId = "asset_id"
        case deviceId = "device_id"
        case userId = "user_id"
        case type, title, description
        case performedBy = "performed_by"
        case performedAt = "performed_at"
        case nextDueDate = "next_due_date"
        case costCents = "cost_cents"
        case currency
        case invoiceDocumentId = "invoice_document_id"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isDue: Bool {
        guard let dueDate = nextDueDate else { return false }
        return dueDate <= Date()
    }

    var isDueSoon: Bool {
        guard let dueDate = nextDueDate else { return false }
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return daysUntilDue >= 0 && daysUntilDue <= 30
    }

    static func == (lhs: MaintenanceRecord, rhs: MaintenanceRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum MaintenanceType: String, Codable, CaseIterable, Identifiable {
    case maintenance
    case repair
    case inspection
    case replacement
    case upgrade

    var id: String { rawValue }

    var displayName: String {
        NSLocalizedString("maintenance_type.\(rawValue)", comment: "")
    }

    var color: Color {
        switch self {
        case .maintenance: return .maintenanceColor
        case .repair: return .repairColor
        case .inspection: return .inspectionColor
        case .replacement: return .replacementColor
        case .upgrade: return .upgradeColor
        }
    }

    var icon: String {
        switch self {
        case .maintenance: return "wrench.fill"
        case .repair: return "hammer.fill"
        case .inspection: return "magnifyingglass"
        case .replacement: return "arrow.triangle.2.circlepath"
        case .upgrade: return "arrow.up.circle.fill"
        }
    }
}
