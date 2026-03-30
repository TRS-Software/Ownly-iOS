import Foundation

struct UserPreferences: Codable {
    var locale: String
    var currency: String
    var theme: AppTheme
    var subscriptionTier: String
    var onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case locale, currency, theme
        case subscriptionTier = "subscription_tier"
        case onboardingCompleted = "onboarding_completed"
    }

    static let `default` = UserPreferences(
        locale: Locale.current.language.languageCode?.identifier ?? "en",
        currency: "EUR",
        theme: .system,
        subscriptionTier: "free",
        onboardingCompleted: false
    )
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return String(localized: "theme.light")
        case .dark: return String(localized: "theme.dark")
        case .system: return String(localized: "theme.system")
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

struct SupportedCurrency: Identifiable {
    let code: String
    let name: String
    let symbol: String
    var id: String { code }

    static let all: [SupportedCurrency] = [
        SupportedCurrency(code: "EUR", name: "Euro", symbol: "€"),
        SupportedCurrency(code: "USD", name: "US Dollar", symbol: "$"),
        SupportedCurrency(code: "GBP", name: "British Pound", symbol: "£"),
        SupportedCurrency(code: "CHF", name: "Swiss Franc", symbol: "CHF"),
        SupportedCurrency(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        SupportedCurrency(code: "CNY", name: "Chinese Yuan", symbol: "¥"),
        SupportedCurrency(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        SupportedCurrency(code: "CAD", name: "Canadian Dollar", symbol: "C$"),
        SupportedCurrency(code: "SEK", name: "Swedish Krona", symbol: "kr"),
        SupportedCurrency(code: "NOK", name: "Norwegian Krone", symbol: "kr"),
        SupportedCurrency(code: "DKK", name: "Danish Krone", symbol: "kr"),
        SupportedCurrency(code: "PLN", name: "Polish Zloty", symbol: "zł"),
        SupportedCurrency(code: "CZK", name: "Czech Koruna", symbol: "Kč"),
        SupportedCurrency(code: "HUF", name: "Hungarian Forint", symbol: "Ft"),
        SupportedCurrency(code: "TRY", name: "Turkish Lira", symbol: "₺"),
        SupportedCurrency(code: "BRL", name: "Brazilian Real", symbol: "R$"),
        SupportedCurrency(code: "MXN", name: "Mexican Peso", symbol: "MX$"),
        SupportedCurrency(code: "INR", name: "Indian Rupee", symbol: "₹"),
        SupportedCurrency(code: "KRW", name: "South Korean Won", symbol: "₩"),
        SupportedCurrency(code: "SGD", name: "Singapore Dollar", symbol: "S$"),
        SupportedCurrency(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$"),
        SupportedCurrency(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$"),
        SupportedCurrency(code: "ZAR", name: "South African Rand", symbol: "R"),
        SupportedCurrency(code: "AED", name: "UAE Dirham", symbol: "د.إ"),
        SupportedCurrency(code: "SAR", name: "Saudi Riyal", symbol: "﷼"),
        SupportedCurrency(code: "THB", name: "Thai Baht", symbol: "฿"),
        SupportedCurrency(code: "RUB", name: "Russian Ruble", symbol: "₽"),
    ]
}

struct SupportedLocale: Identifiable {
    let code: String
    let name: String
    let flag: String
    var id: String { code }

    static let all: [SupportedLocale] = [
        SupportedLocale(code: "de", name: "Deutsch", flag: "🇩🇪"),
        SupportedLocale(code: "en", name: "English", flag: "🇬🇧"),
        SupportedLocale(code: "es", name: "Español", flag: "🇪🇸"),
        SupportedLocale(code: "fr", name: "Français", flag: "🇫🇷"),
        SupportedLocale(code: "it", name: "Italiano", flag: "🇮🇹"),
        SupportedLocale(code: "pt", name: "Português", flag: "🇵🇹"),
        SupportedLocale(code: "tr", name: "Türkçe", flag: "🇹🇷"),
        SupportedLocale(code: "ar", name: "العربية", flag: "🇸🇦"),
        SupportedLocale(code: "ja", name: "日本語", flag: "🇯🇵"),
        SupportedLocale(code: "zh", name: "中文", flag: "🇨🇳"),
    ]
}
