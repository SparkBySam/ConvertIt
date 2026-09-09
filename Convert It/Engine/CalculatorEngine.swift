import Foundation

enum PercentageMode: String, CaseIterable, Identifiable {
    case percentOf
    case whatPercent
    case increase
    case decrease

    var id: String { rawValue }

    var label: String {
        switch self {
        case .percentOf: "X% of Y"
        case .whatPercent: "X is % of Y"
        case .increase: "Y + X%"
        case .decrease: "Y − X%"
        }
    }

    var fieldALabel: String {
        switch self {
        case .percentOf: "Percent"
        case .whatPercent: "Part"
        case .increase, .decrease: "Value"
        }
    }

    var fieldBLabel: String {
        switch self {
        case .percentOf: "Of"
        case .whatPercent: "Whole"
        case .increase, .decrease: "Percent"
        }
    }
}

enum CalculatorEngine {
    static func percentage(mode: PercentageMode, a: Double, b: Double, decimalPlaces: Int? = nil) -> ConversionResult? {
        switch mode {
        case .percentOf:
            let value = b * a / 100
            return ConversionResult(
                value: formatNumber(value, decimalPlaces: decimalPlaces),
                detail: "\(formatNumber(a, decimalPlaces: decimalPlaces))% of \(formatNumber(b, decimalPlaces: decimalPlaces))"
            )
        case .whatPercent:
            guard b != 0 else { return nil }
            let value = a / b * 100
            return ConversionResult(
                value: "\(formatNumber(value, decimalPlaces: decimalPlaces))%",
                detail: "\(formatNumber(a, decimalPlaces: decimalPlaces)) is what % of \(formatNumber(b, decimalPlaces: decimalPlaces))"
            )
        case .increase:
            let value = a * (1 + b / 100)
            return ConversionResult(
                value: formatNumber(value, decimalPlaces: decimalPlaces),
                detail: "\(formatNumber(a, decimalPlaces: decimalPlaces)) increased by \(formatNumber(b, decimalPlaces: decimalPlaces))%"
            )
        case .decrease:
            let value = a * (1 - b / 100)
            return ConversionResult(
                value: formatNumber(value, decimalPlaces: decimalPlaces),
                detail: "\(formatNumber(a, decimalPlaces: decimalPlaces)) decreased by \(formatNumber(b, decimalPlaces: decimalPlaces))%"
            )
        }
    }

    static func tip(bill: Double, tipPercent: Double, split: Int) -> ConversionResult? {
        guard bill >= 0, tipPercent >= 0, split >= 1 else { return nil }

        let tipAmount = bill * tipPercent / 100
        let total = bill + tipAmount
        let perPerson = total / Double(split)

        let detail: String
        if split == 1 {
            detail = "Tip \(formatCurrency(tipAmount)) on \(formatCurrency(bill))"
        } else {
            detail = "Tip \(formatCurrency(tipAmount)) · \(formatCurrency(perPerson)) each"
        }

        return ConversionResult(
            value: formatCurrency(total),
            detail: detail
        )
    }

    private static func formatNumber(_ value: Double, decimalPlaces: Int? = nil) -> String {
        ConversionEngine.formatNumber(value, decimalPlaces: decimalPlaces)
    }

    private static func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}
