import Foundation

enum ConversionUnit: Hashable, Identifiable {
    case fahrenheit
    case celsius
    case kelvin
    case miles
    case kilometers
    case meters
    case feet
    case inches
    case pounds
    case kilograms
    case ounces
    case grams
    case cups
    case milliliters
    case liters
    case fluidOunces
    case tablespoons
    case teaspoons
    case kilobytes
    case megabytes
    case gigabytes
    case terabytes
    case kibibytes
    case mebibytes
    case gibibytes
    case tebibytes
    case milesPerHour
    case kilometersPerHour
    case knots
    case squareFeet
    case squareMeters
    case acres
    case hectares
    case psi
    case bar
    case kilopascals
    case kilowattHours
    case megajoules
    case kilocalories
    case milesPerGallon
    case litersPer100Km
    case currency(String)
    case timeZone(String)

    var id: String {
        switch self {
        case .currency(let code):
            "currency-\(code)"
        case .timeZone(let identifier):
            "tz-\(identifier)"
        default:
            String(describing: self)
        }
    }

    var label: String {
        switch self {
        case .fahrenheit: "°F"
        case .celsius: "°C"
        case .kelvin: "Kelvin"
        case .miles: "Miles"
        case .kilometers: "Kilometers"
        case .meters: "Meters"
        case .feet: "Feet"
        case .inches: "Inches"
        case .pounds: "Pounds"
        case .kilograms: "Kilograms"
        case .ounces: "Ounces"
        case .grams: "Grams"
        case .cups: "Cups"
        case .milliliters: "Milliliters"
        case .liters: "Liters"
        case .fluidOunces: "Fluid Ounces"
        case .tablespoons: "Tablespoons"
        case .teaspoons: "Teaspoons"
        case .kilobytes: "KB"
        case .megabytes: "MB"
        case .gigabytes: "GB"
        case .terabytes: "TB"
        case .kibibytes: "KiB"
        case .mebibytes: "MiB"
        case .gibibytes: "GiB"
        case .tebibytes: "TiB"
        case .milesPerHour: "mph"
        case .kilometersPerHour: "km/h"
        case .knots: "Knots"
        case .squareFeet: "Square Feet"
        case .squareMeters: "Square Meters"
        case .acres: "Acres"
        case .hectares: "Hectares"
        case .psi: "PSI"
        case .bar: "Bar"
        case .kilopascals: "kPa"
        case .kilowattHours: "kWh"
        case .megajoules: "MJ"
        case .kilocalories: "kcal"
        case .milesPerGallon: "MPG"
        case .litersPer100Km: "L/100km"
        case .currency(let code): code
        case .timeZone(let identifier):
            TimeZone(identifier: identifier)?.abbreviation() ?? identifier
        }
    }

    var shortLabel: String {
        switch self {
        case .fahrenheit: "°F"
        case .celsius: "°C"
        case .kelvin: "K"
        case .miles: "mi"
        case .kilometers: "km"
        case .meters: "m"
        case .feet: "ft"
        case .inches: "in"
        case .pounds: "lbs"
        case .kilograms: "kg"
        case .ounces: "oz"
        case .grams: "g"
        case .cups: "cup"
        case .milliliters: "ml"
        case .liters: "L"
        case .fluidOunces: "fl oz"
        case .tablespoons: "tbsp"
        case .teaspoons: "tsp"
        case .kilobytes: "KB"
        case .megabytes: "MB"
        case .gigabytes: "GB"
        case .terabytes: "TB"
        case .kibibytes: "KiB"
        case .mebibytes: "MiB"
        case .gibibytes: "GiB"
        case .tebibytes: "TiB"
        case .milesPerHour: "mph"
        case .kilometersPerHour: "km/h"
        case .knots: "kn"
        case .squareFeet: "ft²"
        case .squareMeters: "m²"
        case .acres: "ac"
        case .hectares: "ha"
        case .psi: "psi"
        case .bar: "bar"
        case .kilopascals: "kPa"
        case .kilowattHours: "kWh"
        case .megajoules: "MJ"
        case .kilocalories: "kcal"
        case .milesPerGallon: "mpg"
        case .litersPer100Km: "L/100km"
        case .currency(let code): code
        case .timeZone(let identifier):
            TimeZone(identifier: identifier)?.abbreviation() ?? identifier
        }
    }

    var currencyCode: String? {
        if case .currency(let code) = self { return code }
        return nil
    }

    var aliases: [String] {
        switch self {
        case .fahrenheit: return ["f", "fahrenheit", "°f", "degf"]
        case .celsius: return ["c", "celsius", "°c", "degc"]
        case .kelvin: return ["k", "kelvin"]
        case .miles: return ["mi", "mile", "miles"]
        case .kilometers: return ["km", "kilometer", "kilometers", "kilometre", "kilometres"]
        case .meters: return ["m", "meter", "meters", "metre", "metres"]
        case .feet: return ["ft", "foot", "feet"]
        case .inches: return ["in", "inch", "inches"]
        case .pounds: return ["lb", "lbs", "pound", "pounds"]
        case .kilograms: return ["kg", "kilogram", "kilograms"]
        case .ounces: return ["oz", "ounce", "ounces"]
        case .grams: return ["g", "gram", "grams"]
        case .cups: return ["cup", "cups"]
        case .milliliters: return ["ml", "milliliter", "milliliters", "millilitre", "millilitres"]
        case .liters: return ["l", "liter", "liters", "litre", "litres"]
        case .fluidOunces: return ["fl oz", "floz", "fl.oz", "fluid oz", "fluid ounce", "fluid ounces"]
        case .tablespoons: return ["tbsp", "tablespoon", "tablespoons"]
        case .teaspoons: return ["tsp", "teaspoon", "teaspoons"]
        case .kilobytes: return ["kb", "kilobyte", "kilobytes"]
        case .megabytes: return ["mb", "megabyte", "megabytes"]
        case .gigabytes: return ["gb", "gigabyte", "gigabytes"]
        case .terabytes: return ["tb", "terabyte", "terabytes"]
        case .kibibytes: return ["kib", "kibibyte", "kibibytes"]
        case .mebibytes: return ["mib", "mebibyte", "mebibytes"]
        case .gibibytes: return ["gib", "gibibyte", "gibibytes"]
        case .tebibytes: return ["tib", "tebibyte", "tebibytes"]
        case .milesPerHour: return ["mph", "mi/h", "mile per hour", "miles per hour"]
        case .kilometersPerHour: return ["km/h", "kmh", "kph", "kmph", "kilometer per hour", "kilometers per hour"]
        case .knots: return ["kn", "knot", "knots", "kt"]
        case .squareFeet: return ["ft2", "ft²", "sqft", "sq ft", "square foot", "square feet"]
        case .squareMeters: return ["m2", "m²", "sqm", "sq m", "square meter", "square meters", "square metre", "square metres"]
        case .acres: return ["ac", "acre", "acres"]
        case .hectares: return ["ha", "hectare", "hectares"]
        case .psi: return ["psi", "pounds per square inch"]
        case .bar: return ["bar", "bars"]
        case .kilopascals: return ["kpa", "kilopascal", "kilopascals"]
        case .kilowattHours: return ["kwh", "kilowatt hour", "kilowatt hours", "kilowatt-hour"]
        case .megajoules: return ["mj", "megajoule", "megajoules"]
        case .kilocalories: return ["kcal", "kilocalorie", "kilocalories", "calorie", "calories"]
        case .milesPerGallon: return ["mpg", "mile per gallon", "miles per gallon", "mi/gal"]
        case .litersPer100Km: return ["l/100km", "l100km", "liters per 100km", "litres per 100km", "lp100"]
        case .currency(let code):
            return [code.lowercased(), code.uppercased()]
        case .timeZone(let identifier):
            var names = [identifier.lowercased()]
            if let tz = TimeZone(identifier: identifier) {
                names.append(tz.abbreviation()?.lowercased() ?? "")
            }
            return names.filter { !$0.isEmpty }
        }
    }

    var category: ConversionCategory? {
        ConversionCategory.allCases.first { $0.units().contains(self) }
    }

    static func resolve(alias: String, in category: ConversionCategory? = nil) -> ConversionUnit? {
        let normalized = alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if let category, category == .currency {
            let code = normalized.uppercased()
            return CurrencyRateStore.supportedCodes.contains(code) ? .currency(code) : nil
        }

        let candidates: [ConversionUnit]
        if let category {
            candidates = category.units()
        } else {
            candidates = ConversionCategory.allCases.flatMap { $0.units() }
        }

        return candidates.first { unit in
            unit.aliases.contains { $0 == normalized } ||
            unit.shortLabel.lowercased() == normalized ||
            unit.label.lowercased() == normalized
        }
    }
}
