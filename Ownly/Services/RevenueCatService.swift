import Foundation
import RevenueCat

final class RevenueCatService {
    static let shared = RevenueCatService()
    private init() {}

    static let entitlementID = "premium"

    // MARK: - Customer Info

    func getCustomerInfo() async throws -> CustomerInfo {
        try await Purchases.shared.customerInfo()
    }

    func isPremium() async -> Bool {
        guard let info = try? await getCustomerInfo() else { return false }
        return info.entitlements[Self.entitlementID]?.isActive == true
    }

    // MARK: - Offerings

    func getOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    func getCurrentOffering() async throws -> Offering? {
        let offerings = try await getOfferings()
        return offerings.current
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        return result.customerInfo
    }

    func restorePurchases() async throws -> CustomerInfo {
        try await Purchases.shared.restorePurchases()
    }

    // MARK: - User Management

    func login(userId: String) async throws {
        _ = try await Purchases.shared.logIn(userId)
    }

    func logout() async throws {
        _ = try await Purchases.shared.logOut()
    }
}
