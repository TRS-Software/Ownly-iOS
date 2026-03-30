import Foundation

@MainActor
final class MaintenanceRepository: ObservableObject {
    static let shared = MaintenanceRepository()
    private let supabase = SupabaseService.shared

    @Published var records: [UUID: [MaintenanceRecord]] = [:] // keyed by assetId
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    func fetchForAsset(_ assetId: UUID) async {
        isLoading = true
        error = nil
        do {
            let userId = try await supabase.requireUserId()
            let result: [MaintenanceRecord] = try await supabase.fetch(
                from: "maintenance_records",
                filters: [
                    ("asset_id", assetId.uuidString),
                    ("user_id", userId.uuidString),
                ],
                orderBy: "performed_at",
                ascending: false
            )
            records[assetId] = result
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(_ record: MaintenanceRecord) async throws {
        try await supabase.insert(into: "maintenance_records", value: record)
        records[record.assetId, default: []].insert(record, at: 0)
    }

    func update(_ record: MaintenanceRecord) async throws {
        let userId = try await supabase.requireUserId()
        guard record.userId == userId else {
            self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
            throw SupabaseSecurityError.ownershipMismatch
        }
        try await supabase.update(table: "maintenance_records", id: record.id, value: record)
        if let index = records[record.assetId]?.firstIndex(where: { $0.id == record.id }) {
            records[record.assetId]?[index] = record
        }
    }

    func delete(id: UUID, assetId: UUID) async throws {
        let userId = try await supabase.requireUserId()
        if let cached = records[assetId]?.first(where: { $0.id == id }) {
            guard cached.userId == userId else {
                self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
                throw SupabaseSecurityError.ownershipMismatch
            }
        } else {
            let record: MaintenanceRecord = try await supabase.fetchSingle(from: "maintenance_records", id: id)
            guard record.userId == userId else {
                self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
                throw SupabaseSecurityError.ownershipMismatch
            }
        }
        try await supabase.delete(from: "maintenance_records", id: id)
        records[assetId]?.removeAll { $0.id == id }
    }

    func recordsForAsset(_ assetId: UUID) -> [MaintenanceRecord] {
        records[assetId] ?? []
    }

    func upcomingMaintenance() -> [MaintenanceRecord] {
        records.values.flatMap { $0 }
            .filter { $0.nextDueDate != nil && !$0.isDue }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    func totalCost(for assetId: UUID) -> Int {
        recordsForAsset(assetId).compactMap(\.costCents).reduce(0, +)
    }
}
