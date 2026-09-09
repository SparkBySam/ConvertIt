import Foundation

struct ParsedQuickInput: Equatable {
    let value: Double
    let fromUnit: ConversionUnit
    let toUnit: ConversionUnit
}

enum QuickParseResult: Equatable {
    case conversion(ParsedQuickInput)
    case percentage(mode: PercentageMode, a: Double, b: Double)
    case tip(bill: Double, tipPercent: Double, split: Int)
    case currency(value: Double, from: String, to: String)
    case timeZone(hour: Int, minute: Int, fromID: String, toID: String)
}

enum QuickInputParser {
    static func parse(_ input: String) -> QuickParseResult? {
        let normalized = normalize(input)
        guard !normalized.isEmpty else { return nil }

        if let tip = parseTip(normalized) { return tip }
        if let percentage = parsePercentage(normalized) { return percentage }
        if let timeZone = parseTimeZone(normalized) { return timeZone }
        if let conversion = parseConversion(normalized) { return conversion }
        if let reverse = parseReverseConversion(normalized) { return reverse }
        return nil
    }

    private static func normalize(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: "→", with: " to ")
            .replacingOccurrences(of: "->", with: " to ")
            .replacingOccurrences(of: "what's", with: "what is", options: .caseInsensitive)
            .replacingOccurrences(of: "whats", with: "what is", options: .caseInsensitive)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .lowercased()
    }

    private static func parseTimeZone(_ text: String) -> QuickParseResult? {
        let patterns = [
            #"^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+(.+?)\s+to\s+(.+)$"#,
            #"^(\d{1,2}):(\d{2})\s+(.+?)\s+to\s+(.+)$"#,
        ]

        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }

            let hourRange = Range(match.range(at: 1), in: text)!
            guard var hour = Int(text[hourRange]) else { continue }

            let minute: Int
            let fromAlias: String
            let toAlias: String

            if index == 0 {
                if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound,
                   let minuteRange = Range(match.range(at: 2), in: text),
                   let parsedMinute = Int(text[minuteRange]) {
                    minute = parsedMinute
                } else {
                    minute = 0
                }

                if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound,
                   let meridiemRange = Range(match.range(at: 3), in: text) {
                    let meridiem = String(text[meridiemRange])
                    if meridiem == "pm", hour < 12 { hour += 12 }
                    if meridiem == "am", hour == 12 { hour = 0 }
                }

                guard match.numberOfRanges > 5,
                      let fromRange = Range(match.range(at: 4), in: text),
                      let toRange = Range(match.range(at: 5), in: text) else { continue }
                fromAlias = String(text[fromRange])
                toAlias = String(text[toRange])
            } else {
                guard let minuteRange = Range(match.range(at: 2), in: text),
                      let fromRange = Range(match.range(at: 3), in: text),
                      let toRange = Range(match.range(at: 4), in: text),
                      let parsedMinute = Int(text[minuteRange]) else { continue }
                minute = parsedMinute
                fromAlias = String(text[fromRange])
                toAlias = String(text[toRange])
            }

            guard hour >= 0, hour <= 23, minute >= 0, minute <= 59,
                  let fromID = TimeZoneResolver.resolve(fromAlias),
                  let toID = TimeZoneResolver.resolve(toAlias) else { continue }

            return .timeZone(hour: hour, minute: minute, fromID: fromID, toID: toID)
        }

        return nil
    }

    private static func parseTip(_ text: String) -> QuickParseResult? {
        let number = #"-?\d+(?:\.\d+)?"#
        let pct = #"(?:%|percent|pct)"#

        let patterns = [
            #"^(?:\#(pct)\s+)?(\#(number))\s*\#(pct)?\s+tip\s+on\s+(\#(number))(?:\s+split\s+(\d+))?$"#,
            #"^tip\s+(\#(number))\s*\#(pct)\s+on\s+(\#(number))(?:\s+split\s+(\d+))?$"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }

            var percent: Double?
            var bill: Double?
            var split = 1

            if pattern.hasPrefix("^(?:") {
                guard let percentRange = Range(match.range(at: 2), in: text),
                      let billRange = Range(match.range(at: 3), in: text),
                      let p = parseNumber(text[percentRange]),
                      let b = parseNumber(text[billRange]) else { continue }
                percent = p
                bill = b
                if match.numberOfRanges > 4, let splitRange = Range(match.range(at: 4), in: text),
                   let s = Int(text[splitRange]) {
                    split = s
                }
            } else {
                guard let percentRange = Range(match.range(at: 1), in: text),
                      let billRange = Range(match.range(at: 2), in: text),
                      let p = parseNumber(text[percentRange]),
                      let b = parseNumber(text[billRange]) else { continue }
                percent = p
                bill = b
                if match.numberOfRanges > 3, let splitRange = Range(match.range(at: 3), in: text),
                   let s = Int(text[splitRange]) {
                    split = s
                }
            }

            if let percent, let bill {
                return .tip(bill: bill, tipPercent: percent, split: max(1, split))
            }
        }

        return nil
    }

    private static func parsePercentage(_ text: String) -> QuickParseResult? {
        let number = #"-?\d+(?:\.\d+)?"#
        let pct = #"(?:%|percent|pct)"#

        let patterns: [(PercentageMode, String)] = [
            (.whatPercent, #"^(?:what\s+\#(pct)\s+is\s+)?(\#(number))\s+of\s+(\#(number))$"#),
            (.whatPercent, #"^(\#(number))\s+is\s+what\s+\#(pct)(?:\s+of)?\s+(\#(number))$"#),
            (.whatPercent, #"^(\#(number))\s+as\s+\#(pct)\s+of\s+(\#(number))$"#),
            (.increase, #"^(\#(number))\s*(?:\+|plus|increased\s+by)\s*(\#(number))\s*\#(pct)?$"#),
            (.decrease, #"^(\#(number))\s*(?:-|minus|decreased\s+by)\s*(\#(number))\s*\#(pct)?$"#),
            (.percentOf, #"^(?:what\s+is\s+)?(\#(number))\s*\#(pct)\s+of\s+(\#(number))$"#),
        ]

        for (mode, pattern) in patterns {
            if let (a, b) = captureTwoNumbers(pattern: pattern, in: text) {
                return .percentage(mode: mode, a: a, b: b)
            }
        }

        return nil
    }

    private static func parseReverseConversion(_ normalized: String) -> QuickParseResult? {
        guard let fromRange = normalized.range(of: " from ") else { return nil }

        let toAlias = String(normalized[..<fromRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let right = String(normalized[fromRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !toAlias.isEmpty, !right.isEmpty else { return nil }

        guard let (value, fromAlias) = extractValueAndUnit(from: right) else { return nil }

        if let toCode = resolveCurrencyCode(toAlias),
           let fromCode = resolveCurrencyCode(fromAlias) {
            return .currency(value: value, from: fromCode, to: toCode)
        }

        guard let toUnit = ConversionUnit.resolve(alias: toAlias) else { return nil }
        guard let fromUnit = ConversionUnit.resolve(alias: fromAlias, in: toUnit.category) ??
              ConversionUnit.resolve(alias: fromAlias) else { return nil }

        guard fromUnit.category == toUnit.category,
              fromUnit.category != .timeZone else { return nil }

        return .conversion(ParsedQuickInput(value: value, fromUnit: fromUnit, toUnit: toUnit))
    }

    private static func parseConversion(_ normalized: String) -> QuickParseResult? {
        guard let toRange = normalized.range(of: " to ") else { return nil }

        let left = String(normalized[..<toRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let right = String(normalized[toRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !left.isEmpty, !right.isEmpty else { return nil }

        guard let (value, fromAlias) = extractValueAndUnit(from: left) else { return nil }

        if let fromCode = resolveCurrencyCode(fromAlias),
           let toCode = resolveCurrencyCode(right) {
            return .currency(value: value, from: fromCode, to: toCode)
        }

        guard let fromUnit = ConversionUnit.resolve(alias: fromAlias) else { return nil }
        guard let toUnit = ConversionUnit.resolve(alias: right, in: fromUnit.category) ??
              ConversionUnit.resolve(alias: right) else { return nil }

        guard fromUnit.category == toUnit.category,
              fromUnit.category != .timeZone else { return nil }

        return .conversion(ParsedQuickInput(value: value, fromUnit: fromUnit, toUnit: toUnit))
    }

    private static func resolveCurrencyCode(_ alias: String) -> String? {
        let code = alias.uppercased()
        return CurrencyRateStore.supportedCodes.contains(code) ? code : nil
    }

    private static func captureTwoNumbers(pattern: String, in text: String) -> (Double, Double)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let firstRange = Range(match.range(at: 1), in: text),
              let secondRange = Range(match.range(at: 2), in: text),
              let first = parseNumber(String(text[firstRange])),
              let second = parseNumber(String(text[secondRange])) else {
            return nil
        }
        return (first, second)
    }

    private static func extractValueAndUnit(from text: String) -> (Double, String)? {
        let pattern = #"^(-?\d+(?:\.\d+)?)\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = parseNumber(String(text[valueRange])) else {
            return nil
        }

        let unit = String(text[unitRange]).trimmingCharacters(in: .whitespaces)
        guard !unit.isEmpty else { return nil }
        return (value, unit)
    }

    private static func parseNumber(_ text: some StringProtocol) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ""))
    }
}
