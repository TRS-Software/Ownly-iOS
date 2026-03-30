import Foundation

extension Int {
    /// Format cents as currency string (e.g., 123456 → "€1,234.56")
    func formattedCurrency(code: String = "EUR", locale: Locale = .current) -> String {
        let value = Double(self) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Convert cents to Double amount
    var asCurrencyDouble: Double {
        Double(self) / 100.0
    }
}

extension Double {
    /// Convert Double amount to cents
    var toCents: Int {
        Int((self * 100).rounded())
    }

    func formattedPercent(decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", self)
    }

    func formattedCompact() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        if abs(self) >= 1_000_000 {
            return String(format: "%.1fM", self / 1_000_000)
        } else if abs(self) >= 1_000 {
            return String(format: "%.1fK", self / 1_000)
        }
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Optional where Wrapped == Int {
    func formattedCurrency(code: String = "EUR", locale: Locale = .current) -> String {
        guard let value = self else { return "–" }
        return value.formattedCurrency(code: code, locale: locale)
    }
}
