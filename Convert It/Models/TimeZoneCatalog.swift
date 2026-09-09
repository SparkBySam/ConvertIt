import Foundation

enum TimeZoneCatalog {
    static let allSorted: [String] = TimeZone.knownTimeZoneIdentifiers.sorted()

    static let common: [String] = {
        var ids = [
            TimeZone.current.identifier,
            "America/New_York",
            "America/Chicago",
            "America/Denver",
            "America/Los_Angeles",
            "America/Phoenix",
            "America/Toronto",
            "America/Vancouver",
            "America/Mexico_City",
            "America/Sao_Paulo",
            "Europe/London",
            "Europe/Paris",
            "Europe/Berlin",
            "Europe/Moscow",
            "Asia/Tokyo",
            "Asia/Shanghai",
            "Asia/Hong_Kong",
            "Asia/Singapore",
            "Asia/Dubai",
            "Asia/Kolkata",
            "Australia/Sydney",
            "Pacific/Auckland",
            "UTC",
        ]
        var seen = Set<String>()
        ids = ids.filter { seen.insert($0).inserted }
        for id in allSorted where ids.count < 40 {
            if seen.insert(id).inserted {
                ids.append(id)
            }
        }
        return ids
    }()

    private static let labels: [String: String] = {
        var map: [String: String] = [:]
        map.reserveCapacity(allSorted.count)
        for id in allSorted {
            map[id] = formatLabel(id)
        }
        return map
    }()

    static func label(for identifier: String) -> String {
        labels[identifier] ?? formatLabel(identifier)
    }

    static func filtered(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return common }
        let lower = trimmed.lowercased()
        return allSorted.filter { id in
            id.lowercased().contains(lower) ||
            label(for: id).lowercased().contains(lower)
        }
    }

    private static func formatLabel(_ identifier: String) -> String {
        let tz = TimeZone(identifier: identifier)
        let abbr = tz?.abbreviation() ?? ""
        let name = identifier.replacingOccurrences(of: "_", with: " ")
        if abbr.isEmpty { return name }
        return "\(name) (\(abbr))"
    }
}
