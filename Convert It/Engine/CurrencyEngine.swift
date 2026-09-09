import Foundation

@Observable
final class CurrencyRateStore {
    static let supportedCodes = [
        "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR",
        "MXN", "BRL", "KRW", "SEK", "NOK", "NZD", "SGD", "HKD", "ZAR", "TRY", "PLN",
    ]

    private enum Keys {
        static let rates = "currencyRates"
        static let updated = "currencyRatesUpdated"
    }

    private(set) var rates: [String: Double] = [:]
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init() {
        loadCache()
    }

    func refreshIfNeeded() async {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < 3600, !rates.isEmpty {
            return
        }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD") else {
            errorMessage = "Invalid API URL."
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
            var updated = response.rates
            updated["USD"] = 1
            rates = updated
            lastUpdated = Date()
            saveCache()
        } catch {
            if rates.isEmpty {
                errorMessage = "Couldn't fetch rates. Check your connection."
            }
        }
    }

    func convert(value: Double, from: String, to: String, decimalPlaces: Int? = nil) -> ConversionResult? {
        let fromCode = from.uppercased()
        let toCode = to.uppercased()
        guard fromCode != toCode else {
            return ConversionResult(value: format(value, code: toCode, decimalPlaces: decimalPlaces), detail: "Same currency")
        }
        guard let fromRate = rates[fromCode], let toRate = rates[toCode], fromRate > 0 else {
            return nil
        }
        let usdAmount = value / fromRate
        let converted = usdAmount * toRate
        let detail: String
        if let lastUpdated {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            detail = "Rates updated \(formatter.localizedString(for: lastUpdated, relativeTo: Date()))"
        } else {
            detail = "Exchange rate"
        }
        return ConversionResult(value: format(converted, code: toCode, decimalPlaces: decimalPlaces), detail: detail)
    }

    private func format(_ value: Double, code: String, decimalPlaces: Int? = nil) -> String {
        if let decimalPlaces, code != "JPY", code != "KRW" {
            return "\(ConversionEngine.formatNumber(value, decimalPlaces: decimalPlaces)) \(code)"
        }

        let absValue = abs(value)
        let formatted: String
        if code == "JPY" || code == "KRW" {
            formatted = String(format: "%.0f", value)
        } else if absValue >= 1000 {
            formatted = String(format: "%.2f", value)
        } else {
            formatted = String(format: "%.4g", value)
        }
        return "\(formatted) \(code)"
    }

    private struct FrankfurterResponse: Decodable {
        let rates: [String: Double]
    }

    private func loadCache() {
        if let stored = UserDefaults.standard.dictionary(forKey: Keys.rates) as? [String: Double] {
            rates = stored
        }
        lastUpdated = UserDefaults.standard.object(forKey: Keys.updated) as? Date
    }

    private func saveCache() {
        UserDefaults.standard.set(rates, forKey: Keys.rates)
        UserDefaults.standard.set(lastUpdated, forKey: Keys.updated)
    }
}
