import SwiftUI

@MainActor
final class AssetListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedType: AssetType?
    @Published var sortOption: AssetSortOption = .dateNewest
    @Published var viewMode: ViewMode = .grid

    enum ViewMode: String {
        case grid, list
    }

    private let repo = AssetRepository.shared

    var filteredAssets: [Asset] {
        let filtered = repo.filtered(by: selectedType, search: searchText)
        return repo.sorted(filtered, by: sortOption)
    }

    var isLoading: Bool { repo.isLoading }
    var isEmpty: Bool { filteredAssets.isEmpty && !isLoading }

    func load() async {
        await repo.fetchAll()
    }

    func deleteAsset(_ asset: Asset) async {
        try? await repo.delete(id: asset.id)
    }
}
