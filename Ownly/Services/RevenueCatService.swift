import Foundation
import RevenueCat

final class RevenueCatService {
    static let shared = RevenueCatService()
    private init() {}

    static let entitlementID = "premium"

    /// Whether RevenueCat was successfully configured with an API key
    var isConfigured: Bool {
        Purchases.isConfigured
    }

    // MARK: - Customer Info

    func getCustomerInfo() async throws -> CustomerInfo {
        guard isConfigured else { throw RevenueCatError.notConfigured }
        return try await Purchases.shared.customerInfo()
    }

    func isPremium() async -> Bool {
        guard isConfigured else { return false }
        guard let info = try? await getCustomerInfo() else { return false }
        return info.entitlements[Self.entitlementID]?.isActive == true
    }

    // MARK: - Offerings

    func getOfferings() async throws -> Offerings {
        guard isConfigured else { throw RevenueCatError.notConfigured }
        return try await Purchases.shared.offerings()
    }

    func getCurrentOffering() async throws -> Offering? {
        let offerings = try await getOfferings()
        return offerings.current
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws -> CustomerInfo {
        guard isConfigured else { throw RevenueCatError.notConfigured }
        let result = try await Purchases.shared.purchase(package: package)
        return result.customerInfo
    }

    func restorePurchases() async throws -> CustomerInfo {
        guard isConfigured else { throw RevenueCatError.notConfigured }
        return try await Purchases.shared.restorePurchases()
    }

    // MARK: - User Management

    func login(userId: String) async throws {
        guard isConfigured else { return }
        _ = try await Purchases.shared.logIn(userId)
    }

    func logout() async throws {
        guard isConfigured else { return }
        _ = try await Purchases.shared.logOut()
    }
}

enum RevenueCatError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "RevenueCat is not configured. Please set REVENUECAT_API_KEY."
        }
    }
}
