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

    /// Locale-aware currency formatting.
    /// Correctly places symbol before/after amount based on locale:
    /// - "de" → "1.234,56 €" (symbol after, comma decimal)
    /// - "en" → "$1,234.56" (symbol before, dot decimal)
    func formatCurrency(_ cents: Int, code: String? = nil) -> String {
        let currencyCode = code ?? currency
        let value = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = currentLocale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year().locale(currentLocale))
    }

    /// Apply language change — sets Apple's preferred languages override
    /// so that String(localized:) picks up the new locale immediately.
    func applyLocaleChange(_ newLocale: String) {
        locale = newLocale
        UserDefaults.standard.set([newLocale], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        // Notify views to re-render by triggering objectWillChange
        objectWillChange.send()
    }
}
