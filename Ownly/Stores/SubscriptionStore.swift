import SwiftUI
import RevenueCat

@MainActor
final class SubscriptionStore: ObservableObject {
    enum Status: String, Codable {
        case free
        case trial
        case premium
        case expiredTrial = "expired_trial"
    }

    @AppStorage("subscriptionStatus") var status: Status = .free
    @AppStorage("trialStartedAt") private var trialStartedAtString: String = ""
    @AppStorage("ocrScansUsed") var ocrScansUsed: Int = 0
    @AppStorage("ocrScansResetMonth") private var ocrScansResetMonth: Int = 0

    let trialDurationDays = 7

    // MARK: - Limits

    struct Limits {
        static let freeAssets = 3
        static let freePhotosPerAsset = 50
        static let freeOcrScansPerMonth = 5
        static let freeDevicesPerAsset = 10
        static let freeMaintenancePerAsset = 20
        static let freeDocumentsPerAsset = 10
    }

    var isPremium: Bool {
        status == .premium || status == .trial
    }

    var isTrialActive: Bool {
        guard status == .trial, let start = trialStartedAt else { return false }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return elapsed < trialDurationDays
    }

    var trialDaysRemaining: Int {
        guard let start = trialStartedAt else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(0, trialDurationDays - elapsed)
    }

    private var trialStartedAt: Date? {
        guard !trialStartedAtString.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: trialStartedAtString)
    }

    // MARK: - Actions

    func startTrial() {
        guard status == .free else { return }
        status = .trial
        trialStartedAtString = ISO8601DateFormatter().string(from: Date())
    }

    func checkAndRefreshStatus() async {
        // Check RevenueCat
        if await RevenueCatService.shared.isPremium() {
            status = .premium
            return
        }

        // Check trial expiry
        if status == .trial && !isTrialActive {
            status = .expiredTrial
        }

        // Reset monthly OCR scans
        let currentMonth = Calendar.current.component(.month, from: Date())
        if currentMonth != ocrScansResetMonth {
            ocrScansUsed = 0
            ocrScansResetMonth = currentMonth
        }
    }

    func incrementOcrScans() {
        ocrScansUsed += 1
    }

    // MARK: - Feature Checks

    func canCreateAsset(currentCount: Int) -> Bool {
        isPremium || currentCount < Limits.freeAssets
    }

    func canAddPhoto(currentCount: Int) -> Bool {
        isPremium || currentCount < Limits.freePhotosPerAsset
    }

    func canUseOcr() -> Bool {
        isPremium || ocrScansUsed < Limits.freeOcrScansPerMonth
    }

    func canAccessFinance() -> Bool {
        isPremium
    }

    func canAccessTax() -> Bool {
        isPremium
    }

    func canExport() -> Bool {
        isPremium
    }
}
