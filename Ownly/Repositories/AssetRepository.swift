import Foundation

@MainActor
final class AssetRepository: ObservableObject {
    static let shared = AssetRepository()
    private let supabase = SupabaseService.shared

    @Published var assets: [Asset] = []
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    func fetchAll() async {
        isLoading = true
        error = nil
        do {
            let userId = try await supabase.requireUserId()
            assets = try await supabase.fetch(
                from: "assets",
                filters: [("user_id", userId.uuidString)],
                orderBy: "created_at",
                ascending: false
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func fetch(id: UUID) async -> Asset? {
        do {
            let userId = try await supabase.requireUserId()
            let asset: Asset = try await supabase.fetchSingle(from: "assets", id: id)
            guard asset.userId == userId else {
                self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
                return nil
            }
            return asset
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func create(_ asset: Asset) async throws {
        let userId = try await supabase.requireUserId()
        var securedAsset = asset
        securedAsset.userId = userId
        try await supabase.insert(into: "assets", value: securedAsset)
        assets.insert(securedAsset, at: 0)
    }

    func update(_ asset: Asset) async throws {
        let userId = try await supabase.requireUserId()
        guard asset.userId == userId else {
            self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
            throw SupabaseSecurityError.ownershipMismatch
        }
        try await supabase.update(table: "assets", id: asset.id, value: asset)
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
        }
    }

    func delete(id: UUID) async throws {
        let userId = try await supabase.requireUserId()
        // Verify ownership before deleting
        guard let asset = assets.first(where: { $0.id == id }), asset.userId == userId else {
            let fetchedAsset: Asset? = try? await supabase.fetchSingle(from: "assets", id: id)
            guard let fetchedAsset, fetchedAsset.userId == userId else {
                self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
                throw SupabaseSecurityError.ownershipMismatch
            }
            try await supabase.delete(from: "assets", id: id)
            assets.removeAll { $0.id == id }
            return
        }
        try await supabase.delete(from: "assets", id: id)
        assets.removeAll { $0.id == id }
    }

    // MARK: - Filtering

    func filtered(by type: AssetType? = nil, search: String = "") -> [Asset] {
        var result = assets
        if let type {
            result = result.filter { $0.assetType == type }
        }
        if !search.isEmpty {
            let query = search.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                ($0.subtitle?.lowercased().contains(query) ?? false) ||
                ($0.description?.lowercased().contains(query) ?? false)
            }
        }
        return result
    }

    func sorted(_ assets: [Asset], by: AssetSortOption) -> [Asset] {
        switch by {
        case .dateNewest: return assets.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest: return assets.sorted { $0.createdAt < $1.createdAt }
        case .nameAZ: return assets.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameZA: return assets.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .valueHigh: return assets.sorted { ($0.displayValueCents ?? 0) > ($1.displayValueCents ?? 0) }
        case .valueLow: return assets.sorted { ($0.displayValueCents ?? 0) < ($1.displayValueCents ?? 0) }
        }
    }
}

enum AssetSortOption: String, CaseIterable, Identifiable {
    case dateNewest
    case dateOldest
    case nameAZ
    case nameZA
    case valueHigh
    case valueLow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateNewest: return String(localized: "sort.date_newest")
        case .dateOldest: return String(localized: "sort.date_oldest")
        case .nameAZ: return String(localized: "sort.name_az")
        case .nameZA: return String(localized: "sort.name_za")
        case .valueHigh: return String(localized: "sort.value_high")
        case .valueLow: return String(localized: "sort.value_low")
        }
    }
}
