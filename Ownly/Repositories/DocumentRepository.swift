import Foundation

@MainActor
final class DocumentRepository: ObservableObject {
    static let shared = DocumentRepository()
    private let supabase = SupabaseService.shared

    @Published var documents: [UUID: [AssetDocument]] = [:]
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    func fetchForAsset(_ assetId: UUID) async {
        isLoading = true
        error = nil
        do {
            let userId = try await supabase.requireUserId()
            let result: [AssetDocument] = try await supabase.fetch(
                from: "documents",
                filters: [
                    ("asset_id", assetId.uuidString),
                    ("user_id", userId.uuidString),
                ],
                orderBy: "created_at",
                ascending: false
            )
            documents[assetId] = result
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(_ document: AssetDocument) async throws {
        try await supabase.insert(into: "documents", value: document)
        documents[document.assetId, default: []].insert(document, at: 0)
    }

    func delete(id: UUID, assetId: UUID) async throws {
        let userId = try await supabase.requireUserId()
        if let cached = documents[assetId]?.first(where: { $0.id == id }) {
            guard cached.userId == userId else {
                self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
                throw SupabaseSecurityError.ownershipMismatch
            }
        } else {
            let doc: AssetDocument = try await supabase.fetchSingle(from: "documents", id: id)
            guard doc.userId == userId else {
                self.error = SupabaseSecurityError.ownershipMismatch.localizedDescription
                throw SupabaseSecurityError.ownershipMismatch
            }
        }
        try await supabase.delete(from: "documents", id: id)
        documents[assetId]?.removeAll { $0.id == id }
    }

    func documentsForAsset(_ assetId: UUID) -> [AssetDocument] {
        documents[assetId] ?? []
    }
}
