import Foundation
import SwiftUI

struct Device: Codable, Identifiable, Hashable {
    let id: UUID
    var assetId: UUID
    var userId: UUID
    var name: String
    var category: DeviceCategory
    var manufacturer: String?
    var model: String?
    var serialNumber: String?
    var installationDate: Date?
    var warrantyUntil: Date?
    var expectedLifetimeYears: Int?
    var metadata: [String: AnyCodable]
    var manualUrl: String?
    var status: DeviceStatus
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case assetId = "asset_id"
        case userId = "user_id"
        case name, category, manufacturer, model
        case serialNumber = "serial_number"
        case installationDate = "installation_date"
        case warrantyUntil = "warranty_until"
        case expectedLifetimeYears = "expected_lifetime_years"
        case metadata
        case manualUrl = "manual_url"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isWarrantyActive: Bool {
        guard let warranty = warrantyUntil else { return false }
        return warranty > Date()
    }

    var warrantyRemainingDays: Int? {
        guard let warranty = warrantyUntil else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: warranty).day
    }

    var expectedEndOfLife: Date? {
        guard let installation = installationDate, let years = expectedLifetimeYears else { return nil }
        return Calendar.current.date(byAdding: .year, value: years, to: installation)
    }

    var lifetimeProgressPercent: Double? {
        guard let installation = installationDate, let eol = expectedEndOfLife else { return nil }
        let total = eol.timeIntervalSince(installation)
        let elapsed = Date().timeIntervalSince(installation)
        guard total > 0 else { return nil }
        return min(max(elapsed / total, 0), 1.0)
    }

    static func == (lhs: Device, rhs: Device) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DeviceStatus: String, Codable, CaseIterable {
    case active
    case maintenance
    case replaced
    case defective

    var displayName: String {
        String(localized: LocalizedStringResource(stringLiteral: "device_status.\(rawValue)"))
    }

    var color: Color {
        switch self {
        case .active: return .deviceActive
        case .maintenance: return .deviceMaintenance
        case .replaced: return .deviceReplaced
        case .defective: return .deviceDefective
        }
    }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .maintenance: return "wrench.fill"
        case .replaced: return "arrow.triangle.2.circlepath"
        case .defective: return "exclamationmark.triangle.fill"
        }
    }
}

enum DeviceCategory: String, Codable, CaseIterable, Identifiable {
    // Property
    case heating
    case sanitary
    case electrical
    case roof
    case windows
    case doors
    case kitchen
    // Vehicle
    case engine
    case brakes
    case tires
    case battery
    case exhaust
    case suspension
    // Electronics
    case display
    case storage
    // General
    case other

    var id: String { rawValue }

    var displayName: String {
        String(localized: LocalizedStringResource(stringLiteral: "device_category.\(rawValue)"))
    }

    var icon: String {
        switch self {
        case .heating: return "flame.fill"
        case .sanitary: return "drop.fill"
        case .electrical: return "bolt.fill"
        case .roof: return "house.fill"
        case .windows: return "window.vertical.open"
        case .doors: return "door.left.hand.open"
        case .kitchen: return "fork.knife"
        case .engine: return "engine.combustion.fill"
        case .brakes: return "circle.circle.fill"
        case .tires: return "circle.dashed"
        case .battery: return "battery.100percent"
        case .exhaust: return "wind"
        case .suspension: return "arrow.up.arrow.down"
        case .display: return "display"
        case .storage: return "internaldrive.fill"
        case .other: return "wrench.and.screwdriver.fill"
        }
    }
}
