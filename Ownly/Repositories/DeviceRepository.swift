import Foundation

@MainActor
final class DeviceRepository: ObservableObject {
    static let shared = DeviceRepository()
    private let supabase = SupabaseService.shared

    @Published var devices: [UUID: [Device]] = [:] // keyed by assetId
    @Published var isLoading = false

    private init() {}

    func fetchForAsset(_ assetId: UUID) async {
        isLoading = true
        do {
            let result: [Device] = try await supabase.fetch(
                from: "devices",
                filters: [("asset_id", assetId.uuidString)],
                orderBy: "created_at",
                ascending: false
            )
            devices[assetId] = result
        } catch {
            print("DeviceRepository error: \(error)")
        }
        isLoading = false
    }

    func create(_ device: Device) async throws {
        try await supabase.insert(into: "devices", value: device)
        devices[device.assetId, default: []].insert(device, at: 0)
    }

    func update(_ device: Device) async throws {
        try await supabase.update(table: "devices", id: device.id, value: device)
        if let index = devices[device.assetId]?.firstIndex(where: { $0.id == device.id }) {
            devices[device.assetId]?[index] = device
        }
    }

    func delete(id: UUID, assetId: UUID) async throws {
        try await supabase.delete(from: "devices", id: id)
        devices[assetId]?.removeAll { $0.id == id }
    }

    func devicesForAsset(_ assetId: UUID) -> [Device] {
        devices[assetId] ?? []
    }
}
