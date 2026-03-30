import Foundation
import Supabase

// MARK: - Security Errors

enum SupabaseSecurityError: LocalizedError {
    case notAuthenticated
    case ownershipMismatch
    case invalidFileType(String)
    case fileTooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "error.not_authenticated", defaultValue: "You must be signed in to perform this action.")
        case .ownershipMismatch:
            return String(localized: "error.ownership_mismatch", defaultValue: "You do not have permission to modify this resource.")
        case .invalidFileType(let ext):
            return String(localized: "error.invalid_file_type \(ext)", defaultValue: "File type '\(ext)' is not allowed. Allowed: jpg, png, pdf, webp.")
        case .fileTooLarge(let bytes):
            let mb = bytes / (1024 * 1024)
            return String(localized: "error.file_too_large \(mb)", defaultValue: "File is too large (\(mb) MB). Maximum allowed: 10 MB.")
        }
    }
}

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    /// Maximum allowed upload file size: 10 MB
    static let maxUploadBytes = 10 * 1024 * 1024

    /// Allowed file extensions for uploads
    static let allowedFileExtensions: Set<String> = ["jpg", "jpeg", "png", "pdf", "webp"]

    /// Mapping from file extension to MIME content type
    private static let extensionToContentType: [String: String] = [
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "pdf": "application/pdf",
        "webp": "image/webp",
    ]

    /// Duration in seconds for signed storage URLs
    private static let signedUrlDuration: Int = 3600

    private init() {
        let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""

        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
    }

    // MARK: - Auth Helpers

    var currentUserId: UUID? {
        get async {
            try? await client.auth.session.user.id
        }
    }

    /// Returns the current user's ID or throws if not authenticated.
    /// Use this before any operation that requires an authenticated user.
    func requireUserId() async throws -> UUID {
        guard let userId = await currentUserId else {
            throw SupabaseSecurityError.notAuthenticated
        }
        return userId
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

    /// Validates file extension against allowlist and returns the appropriate content type.
    func validateFileType(path: String) throws -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        guard Self.allowedFileExtensions.contains(ext) else {
            throw SupabaseSecurityError.invalidFileType(ext.isEmpty ? "(none)" : ext)
        }
        return Self.extensionToContentType[ext] ?? "application/octet-stream"
    }

    /// Uploads a file with validation (type + size) and returns a signed URL instead of a public URL.
    func uploadFile(bucket: String, path: String, data: Data, contentType: String? = nil) async throws -> String {
        // Validate file size
        guard data.count <= Self.maxUploadBytes else {
            throw SupabaseSecurityError.fileTooLarge(data.count)
        }

        // Validate file type and resolve content type
        let resolvedContentType: String
        if let contentType {
            // If caller provides content type, still validate the extension
            _ = try validateFileType(path: path)
            resolvedContentType = contentType
        } else {
            resolvedContentType = try validateFileType(path: path)
        }

        try await client.storage.from(bucket)
            .upload(path, data: data, options: .init(contentType: resolvedContentType))

        // Return a signed URL instead of a public URL for security
        return try await createSignedUrl(bucket: bucket, path: path)
    }

    /// Creates a time-limited signed URL for secure access to stored files.
    func createSignedUrl(bucket: String, path: String, expiresIn: Int? = nil) async throws -> String {
        let duration = expiresIn ?? Self.signedUrlDuration
        let url = try await client.storage.from(bucket)
            .createSignedURL(path: path, expiresIn: duration)
        return url.absoluteString
    }

    func deleteFile(bucket: String, paths: [String]) async throws {
        try await client.storage.from(bucket).remove(paths: paths)
    }
}
