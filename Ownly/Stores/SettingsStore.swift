import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @AppStorage("theme") var theme: AppTheme = .system
    @AppStorage("locale") var locale: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("currency") var currency: String = "EUR"
    @AppStorage("remindersEnabled") var remindersEnabled: Bool = true
    @AppStorage("cloudSyncEnabled") var cloudSyncEnabled: Bool = true

    var resolvedColorScheme: ColorScheme? {
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var currentLocale: Locale {
        Locale(identifier: locale)
    }

    func formatCurrency(_ cents: Int, code: String? = nil) -> String {
        cents.formattedCurrency(code: code ?? currency, locale: currentLocale)
    }

    func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year().locale(currentLocale))
    }
}
