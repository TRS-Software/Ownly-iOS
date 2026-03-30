import Foundation

@MainActor
final class AssetRepository: ObservableObject {
    static let shared = AssetRepository()
    private let supabase = SupabaseService.shared

    @Published var assets: [Asset] = []
    @Published var isLoading = false
    @Published var error: Error?

    private init() {}

    func fetchAll() async {
        isLoading = true
        error = nil
        do {
            assets = try await supabase.fetch(
                from: "assets",
                orderBy: "created_at",
                ascending: false
            )
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func fetch(id: UUID) async -> Asset? {
        try? await supabase.fetchSingle(from: "assets", id: id)
    }

    func create(_ asset: Asset) async throws {
        try await supabase.insert(into: "assets", value: asset)
        assets.insert(asset, at: 0)
    }

    func update(_ asset: Asset) async throws {
        try await supabase.update(table: "assets", id: asset.id, value: asset)
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
        }
    }

    func delete(id: UUID) async throws {
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
