import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""

        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
    }

    // MARK: - Generic CRUD

    func fetch<T: Decodable>(
        from table: String,
        filters: [(column: String, value: String)] = [],
        orderBy: String? = nil,
        ascending: Bool = false,
        limit: Int? = nil
    ) async throws -> [T] {
        var query = client.from(table).select()

        for filter in filters {
            query = query.eq(filter.column, value: filter.value)
        }

        if let orderBy {
            query = query.order(orderBy, ascending: ascending)
        }

        if let limit {
            query = query.limit(limit)
        }

        return try await query.execute().value
    }

    func fetchSingle<T: Decodable>(from table: String, id: UUID) async throws -> T {
        try await client.from(table)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func insert<T: Encodable>(into table: String, value: T) async throws {
        try await client.from(table)
            .insert(value)
            .execute()
    }

    func update<T: Encodable>(table: String, id: UUID, value: T) async throws {
        try await client.from(table)
            .update(value)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func delete(from table: String, id: UUID) async throws {
        try await client.from(table)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Storage

    func uploadFile(bucket: String, path: String, data: Data, contentType: String = "image/jpeg") async throws -> String {
        try await client.storage.from(bucket)
            .upload(path, data: data, options: .init(contentType: contentType))

        return try client.storage.from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }

    func deleteFile(bucket: String, paths: [String]) async throws {
        try await client.storage.from(bucket).remove(paths: paths)
    }

    // MARK: - Auth Helpers

    var currentUserId: UUID? {
        get async {
            try? await client.auth.session.user.id
        }
    }
}
