import Foundation

enum ConversionCategory: String, CaseIterable, Identifiable {
    case temperature
    case distance
    case weight
    case volume
    case dataSize
    case speed
    case area
    case pressure
    case energy
    case fuelEconomy
    case timeZone
    case currency
    case percentage
    case tip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .temperature: "Temperature"
        case .distance: "Distance"
        case .weight: "Weight"
        case .volume: "Volume"
        case .dataSize: "Data Size"
        case .speed: "Speed"
        case .area: "Area"
        case .pressure: "Pressure"
        case .energy: "Energy"
        case .fuelEconomy: "Fuel Economy"
        case .timeZone: "Time Zones"
        case .currency: "Currency"
        case .percentage: "Percentage"
        case .tip: "Tip"
        }
    }

    var isCalculator: Bool {
        self == .percentage || self == .tip
    }

    func units(dataSizeBinary: Bool = false) -> [ConversionUnit] {
        switch self {
        case .temperature:
            return [.fahrenheit, .celsius, .kelvin]
        case .distance:
            return [.miles, .kilometers, .meters, .feet, .inches]
        case .weight:
            return [.pounds, .kilograms, .ounces, .grams]
        case .volume:
            return [.cups, .milliliters, .liters, .fluidOunces, .tablespoons, .teaspoons]
        case .dataSize:
            if dataSizeBinary {
                return [.kibibytes, .mebibytes, .gibibytes, .tebibytes]
            }
            return [.kilobytes, .megabytes, .gigabytes, .terabytes]
        case .speed:
            return [.milesPerHour, .kilometersPerHour, .knots]
        case .area:
            return [.squareFeet, .squareMeters, .acres, .hectares]
        case .pressure:
            return [.psi, .bar, .kilopascals]
        case .energy:
            return [.kilowattHours, .megajoules, .kilocalories]
        case .fuelEconomy:
            return [.milesPerGallon, .litersPer100Km]
        case .currency:
            return CurrencyRateStore.supportedCodes.map { .currency($0) }
        case .timeZone, .percentage, .tip:
            return []
        }
    }
}
