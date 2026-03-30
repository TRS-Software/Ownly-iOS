import Foundation

@MainActor
final class TimelineRepository: ObservableObject {
    static let shared = TimelineRepository()
    private let supabase = SupabaseService.shared

    @Published var entries: [UUID: [TimelineEntry]] = [:]
    @Published var isLoading = false

    private init() {}

    func fetchForAsset(_ assetId: UUID) async {
        isLoading = true
        do {
            let result: [TimelineEntry] = try await supabase.fetch(
                from: "timeline_entries",
                filters: [("asset_id", assetId.uuidString)],
                orderBy: "occurred_at",
                ascending: false
            )
            entries[assetId] = result
        } catch {
            print("TimelineRepository error: \(error)")
        }
        isLoading = false
    }

    func entriesForAsset(_ assetId: UUID) -> [TimelineEntry] {
        entries[assetId] ?? []
    }

    func recentEntries(limit: Int = 10) -> [TimelineEntry] {
        entries.values.flatMap { $0 }
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(limit)
            .map { $0 }
    }
}
