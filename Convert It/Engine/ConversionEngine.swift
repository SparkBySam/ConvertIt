import Foundation

struct ConversionResult: Equatable {
    let value: String
    let detail: String?

    static let empty = ConversionResult(value: "—", detail: nil)

    var copyText: String {
        if let detail, !detail.isEmpty {
            return "\(value)\n\(detail)"
        }
        return value
    }

    var numericValue: String {
        value.split(separator: " ").first.map(String.init) ?? value
    }
}

enum ConversionEngine {
    static func convert(
        value: Double,
        from: ConversionUnit,
        to: ConversionUnit,
        dataSizeBinary: Bool = false,
        decimalPlaces: Int? = nil
    ) -> ConversionResult? {
        if case .timeZone = from, case .timeZone = to {
            return nil
        }

        if case .currency(let fromCode) = from, case .currency(let toCode) = to {
            return nil
        }

        if from.category == .fuelEconomy, to.category == .fuelEconomy {
            return convertFuelEconomy(value: value, from: from, to: to, decimalPlaces: decimalPlaces)
        }

        if let fromBytes = storageBytesPerUnit(from, binary: dataSizeBinary),
           let toBytes = storageBytesPerUnit(to, binary: dataSizeBinary) {
            let bytes = value * fromBytes
            let converted = bytes / toBytes
            return ConversionResult(
                value: formatDataSize(converted, unit: to, decimalPlaces: decimalPlaces),
                detail: nil
            )
        }

        if let fromStorage = decimalInformationStorageUnit(from),
           let toStorage = decimalInformationStorageUnit(to) {
            let converted = Measurement(value: value, unit: fromStorage)
                .converted(to: toStorage)
                .value
            return ConversionResult(
                value: formatDataSize(converted, unit: to, decimalPlaces: decimalPlaces),
                detail: nil
            )
        }

        guard let baseValue = toBase(value: value, unit: from),
              let result = fromBase(baseValue, to: to) else {
            return nil
        }

        return ConversionResult(
            value: format(result.value, unit: to, decimalPlaces: decimalPlaces),
            detail: result.detail
        )
    }

    static func convertTime(
        date: Date,
        hour: Int,
        minute: Int,
        from timeZoneID: String,
        to targetTimeZoneID: String
    ) -> ConversionResult? {
        guard let fromTZ = TimeZone(identifier: timeZoneID),
              let toTZ = TimeZone(identifier: targetTimeZoneID) else {
            return nil
        }

        var calendar = Calendar.current
        calendar.timeZone = fromTZ

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let sourceDate = calendar.date(from: components) else {
            return nil
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = toTZ
        timeFormatter.dateFormat = "h:mm a"

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = toTZ
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let fromAbbr = fromTZ.abbreviation(for: sourceDate) ?? timeZoneID
        let toAbbr = toTZ.abbreviation(for: sourceDate) ?? targetTimeZoneID

        return ConversionResult(
            value: timeFormatter.string(from: sourceDate),
            detail: "\(dateFormatter.string(from: sourceDate)) · \(String(format: "%02d:%02d", hour, minute)) \(fromAbbr) → \(toAbbr)"
        )
    }

    private static func convertFuelEconomy(
        value: Double,
        from: ConversionUnit,
        to: ConversionUnit,
        decimalPlaces: Int?
    ) -> ConversionResult? {
        guard value > 0 else { return nil }

        let converted: Double
        switch (from, to) {
        case (.milesPerGallon, .litersPer100Km):
            converted = 235.214583 / value
        case (.litersPer100Km, .milesPerGallon):
            converted = 235.214583 / value
        default:
            converted = value
        }

        return ConversionResult(
            value: format(converted, unit: to, decimalPlaces: decimalPlaces),
            detail: nil
        )
    }

    private static func toBase(value: Double, unit: ConversionUnit) -> Double? {
        switch unit {
        case .fahrenheit: (value - 32) * 5 / 9 + 273.15
        case .celsius: value + 273.15
        case .kelvin: value
        case .miles: value * 1609.344
        case .kilometers: value * 1000
        case .meters: value
        case .feet: value * 0.3048
        case .inches: value * 0.0254
        case .pounds: value * 453.59237
        case .kilograms: value * 1000
        case .ounces: value * 28.349523125
        case .grams: value
        case .cups: value * 236.5882365
        case .milliliters: value
        case .liters: value * 1000
        case .fluidOunces: value * 29.5735295625
        case .tablespoons: value * 14.78676478125
        case .teaspoons: value * 4.92892159375
        case .kilobytes, .megabytes, .gigabytes, .terabytes,
             .kibibytes, .mebibytes, .gibibytes, .tebibytes: nil
        case .milesPerHour: value * 0.44704
        case .kilometersPerHour: value / 3.6
        case .knots: value * 0.514444
        case .squareFeet: value * 0.09290304
        case .squareMeters: value
        case .acres: value * 4046.8564224
        case .hectares: value * 10_000
        case .psi: value * 6894.757293168
        case .bar: value * 100_000
        case .kilopascals: value * 1000
        case .kilowattHours: value * 3_600_000
        case .megajoules: value * 1_000_000
        case .kilocalories: value * 4184
        case .milesPerGallon, .litersPer100Km: nil
        case .currency, .timeZone: nil
        }
    }

    private static func fromBase(_ base: Double, to unit: ConversionUnit) -> (value: Double, detail: String?)? {
        switch unit {
        case .fahrenheit:
            return ((base - 273.15) * 9 / 5 + 32, nil)
        case .celsius:
            return (base - 273.15, nil)
        case .kelvin:
            return (base, nil)
        case .miles:
            return (base / 1609.344, nil)
        case .kilometers:
            return (base / 1000, nil)
        case .meters:
            return (base, nil)
        case .feet:
            return (base / 0.3048, nil)
        case .inches:
            return (base / 0.0254, nil)
        case .pounds:
            return (base / 453.59237, nil)
        case .kilograms:
            return (base / 1000, nil)
        case .ounces:
            return (base / 28.349523125, nil)
        case .grams:
            return (base, nil)
        case .cups:
            return (base / 236.5882365, nil)
        case .milliliters:
            return (base, nil)
        case .liters:
            return (base / 1000, nil)
        case .fluidOunces:
            return (base / 29.5735295625, nil)
        case .tablespoons:
            return (base / 14.78676478125, nil)
        case .teaspoons:
            return (base / 4.92892159375, nil)
        case .kilobytes, .megabytes, .gigabytes, .terabytes,
             .kibibytes, .mebibytes, .gibibytes, .tebibytes:
            return nil
        case .milesPerHour:
            return (base / 0.44704, nil)
        case .kilometersPerHour:
            return (base * 3.6, nil)
        case .knots:
            return (base / 0.514444, nil)
        case .squareFeet:
            return (base / 0.09290304, nil)
        case .squareMeters:
            return (base, nil)
        case .acres:
            return (base / 4046.8564224, nil)
        case .hectares:
            return (base / 10_000, nil)
        case .psi:
            return (base / 6894.757293168, nil)
        case .bar:
            return (base / 100_000, nil)
        case .kilopascals:
            return (base / 1000, nil)
        case .kilowattHours:
            return (base / 3_600_000, nil)
        case .megajoules:
            return (base / 1_000_000, nil)
        case .kilocalories:
            return (base / 4184, nil)
        case .milesPerGallon, .litersPer100Km:
            return nil
        case .currency, .timeZone:
            return nil
        }
    }

    static func format(_ value: Double, unit: ConversionUnit, decimalPlaces: Int? = nil) -> String {
        let formatted = formatNumber(value, decimalPlaces: decimalPlaces)
        return "\(formatted) \(unit.shortLabel)"
    }

    static func formatNumber(_ value: Double, decimalPlaces: Int? = nil) -> String {
        if let decimalPlaces {
            return String(format: "%.\(max(0, min(decimalPlaces, 10)))f", value)
        }

        let absValue = abs(value)
        if absValue >= 1_000_000 || (absValue > 0 && absValue < 0.001) {
            return String(format: "%.6g", value)
        }
        if absValue >= 100 {
            return String(format: "%.2f", value)
        }
        return String(format: "%.4g", value)
    }

    private static func decimalInformationStorageUnit(_ unit: ConversionUnit) -> UnitInformationStorage? {
        switch unit {
        case .kilobytes: .kilobytes
        case .megabytes: .megabytes
        case .gigabytes: .gigabytes
        case .terabytes: .terabytes
        default: nil
        }
    }

    private static func storageBytesPerUnit(_ unit: ConversionUnit, binary: Bool) -> Double? {
        if binary {
            switch unit {
            case .kibibytes: 1024
            case .mebibytes: 1024 * 1024
            case .gibibytes: 1024 * 1024 * 1024
            case .tebibytes: 1024 * 1024 * 1024 * 1024
            default: nil
            }
        } else {
            switch unit {
            case .kilobytes: 1_000
            case .megabytes: 1_000 * 1_000
            case .gigabytes: 1_000 * 1_000 * 1_000
            case .terabytes: 1_000 * 1_000 * 1_000 * 1_000
            default: nil
            }
        }
    }

    private static func formatDataSize(_ value: Double, unit: ConversionUnit, decimalPlaces: Int?) -> String {
        let formatted = formatNumber(value, decimalPlaces: decimalPlaces)
        return "\(formatted) \(unit.shortLabel)"
    }
}
