import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let ownlyPrimary = Color("AccentColor", bundle: nil)
    static let ownlyPrimaryFallback = Color(red: 0.35, green: 0.56, blue: 1.0) // #5990FF

    // MARK: - Semantic Colors
    static let ownlyBackground = Color(.systemBackground)
    static let ownlySecondaryBackground = Color(.secondarySystemBackground)
    static let ownlyTertiaryBackground = Color(.tertiarySystemBackground)
    static let ownlyGroupedBackground = Color(.systemGroupedBackground)
    static let ownlySecondaryGroupedBackground = Color(.secondarySystemGroupedBackground)

    static let ownlyTextPrimary = Color(.label)
    static let ownlyTextSecondary = Color(.secondaryLabel)
    static let ownlyTextTertiary = Color(.tertiaryLabel)

    static let ownlySeparator = Color(.separator)
    static let ownlyFill = Color(.systemFill)
    static let ownlySecondaryFill = Color(.secondarySystemFill)

    // MARK: - Status Colors
    static let ownlySuccess = Color.green
    static let ownlyWarning = Color.orange
    static let ownlyError = Color.red
    static let ownlyInfo = Color.blue

    // MARK: - Asset Type Colors
    static let assetProperty = Color(red: 0.35, green: 0.56, blue: 1.0)
    static let assetVehicle = Color(red: 0.56, green: 0.35, blue: 1.0)
    static let assetLuxury = Color(red: 1.0, green: 0.76, blue: 0.03)
    static let assetElectronics = Color(red: 0.0, green: 0.82, blue: 0.76)
    static let assetFinancial = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let assetOther = Color(red: 0.6, green: 0.6, blue: 0.65)

    // MARK: - Maintenance Type Colors
    static let maintenanceColor = Color.blue
    static let repairColor = Color.orange
    static let inspectionColor = Color.purple
    static let replacementColor = Color.red
    static let upgradeColor = Color.green

    // MARK: - Device Status Colors
    static let deviceActive = Color.green
    static let deviceMaintenance = Color.orange
    static let deviceReplaced = Color.gray
    static let deviceDefective = Color.red
}

extension ShapeStyle where Self == Color {
    static var ownlyPrimary: Color { .ownlyPrimary }
}
