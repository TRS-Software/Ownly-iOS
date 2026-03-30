import SwiftUI

@MainActor
final class EngagementStore: ObservableObject {
    @AppStorage("sessionsCount") var sessionsCount: Int = 0
    @AppStorage("assetsCreated") var assetsCreated: Int = 0
    @AppStorage("maintenanceAdded") var maintenanceAdded: Int = 0
    @AppStorage("photosAdded") var photosAdded: Int = 0
    @AppStorage("documentsUploaded") var documentsUploaded: Int = 0
    @AppStorage("ocrScans") var ocrScans: Int = 0
    @AppStorage("paywallShown") var paywallShown: Int = 0
    @AppStorage("paywallDismissed") var paywallDismissed: Int = 0
    @AppStorage("lastRatingPrompt") private var lastRatingPromptString: String = ""
    @AppStorage("ratingTimesPrompted") var ratingTimesPrompted: Int = 0

    func incrementSessions() { sessionsCount += 1 }
    func trackAssetCreated() { assetsCreated += 1 }
    func trackMaintenanceAdded() { maintenanceAdded += 1 }
    func trackPhotoAdded() { photosAdded += 1 }
    func trackDocumentUploaded() { documentsUploaded += 1 }
    func trackOcrScan() { ocrScans += 1 }
    func trackPaywallShown() { paywallShown += 1 }
    func trackPaywallDismissed() { paywallDismissed += 1 }

    var shouldPromptRating: Bool {
        guard ratingTimesPrompted < 3 else { return false }
        guard sessionsCount >= 5 || assetsCreated >= 2 || maintenanceAdded >= 3 else { return false }

        if let lastDate = ISO8601DateFormatter().date(from: lastRatingPromptString) {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            return daysSince >= 30
        }
        return true
    }

    func markRatingPrompted() {
        ratingTimesPrompted += 1
        lastRatingPromptString = ISO8601DateFormatter().string(from: Date())
    }
}
