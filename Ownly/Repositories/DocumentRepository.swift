import Foundation

@MainActor
final class DocumentRepository: ObservableObject {
    static let shared = DocumentRepository()
    private let supabase = SupabaseService.shared

    @Published var documents: [UUID: [AssetDocument]] = [:]
    @Published var isLoading = false

    private init() {}

    func fetchForAsset(_ assetId: UUID) async {
        isLoading = true
        do {
            let result: [AssetDocument] = try await supabase.fetch(
                from: "documents",
                filters: [("asset_id", assetId.uuidString)],
                orderBy: "created_at",
                ascending: false
            )
            documents[assetId] = result
        } catch {
            print("DocumentRepository error: \(error)")
        }
        isLoading = false
    }

    func create(_ document: AssetDocument) async throws {
        try await supabase.insert(into: "documents", value: document)
        documents[document.assetId, default: []].insert(document, at: 0)
    }

    func delete(id: UUID, assetId: UUID) async throws {
        try await supabase.delete(from: "documents", id: id)
        documents[assetId]?.removeAll { $0.id == id }
    }

    func documentsForAsset(_ assetId: UUID) -> [AssetDocument] {
        documents[assetId] ?? []
    }
}
