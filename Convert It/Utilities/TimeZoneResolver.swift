import Foundation

enum TimeZoneResolver {
    private static let aliasMap: [String: String] = {
        var map: [String: String] = [
            "utc": "UTC",
            "gmt": "UTC",
            "z": "UTC",
            "est": "America/New_York",
            "edt": "America/New_York",
            "et": "America/New_York",
            "cst": "America/Chicago",
            "cdt": "America/Chicago",
            "ct": "America/Chicago",
            "mst": "America/Denver",
            "mdt": "America/Denver",
            "mt": "America/Denver",
            "pst": "America/Los_Angeles",
            "pdt": "America/Los_Angeles",
            "pt": "America/Los_Angeles",
            "akst": "America/Anchorage",
            "akdt": "America/Anchorage",
            "hst": "Pacific/Honolulu",
            "tokyo": "Asia/Tokyo",
            "jst": "Asia/Tokyo",
            "london": "Europe/London",
            "bst": "Europe/London",
            "paris": "Europe/Paris",
            "cet": "Europe/Paris",
            "berlin": "Europe/Berlin",
            "moscow": "Europe/Moscow",
            "msk": "Europe/Moscow",
            "dubai": "Asia/Dubai",
            "ist": "Asia/Kolkata",
            "india": "Asia/Kolkata",
            "singapore": "Asia/Singapore",
            "sgt": "Asia/Singapore",
            "shanghai": "Asia/Shanghai",
            "beijing": "Asia/Shanghai",
            "hong kong": "Asia/Hong_Kong",
            "hk": "Asia/Hong_Kong",
            "sydney": "Australia/Sydney",
            "aest": "Australia/Sydney",
            "auckland": "Pacific/Auckland",
            "nzst": "Pacific/Auckland",
            "toronto": "America/Toronto",
            "vancouver": "America/Vancouver",
            "denver": "America/Denver",
            "chicago": "America/Chicago",
            "la": "America/Los_Angeles",
            "los angeles": "America/Los_Angeles",
            "nyc": "America/New_York",
            "new york": "America/New_York",
        ]

        for id in TimeZone.knownTimeZoneIdentifiers {
            let lower = id.lowercased()
            map[lower] = id
            let city = id.split(separator: "/").last.map(String.init)?.lowercased() ?? ""
            if !city.isEmpty {
                map[city.replacingOccurrences(of: "_", with: " ")] = id
                map[city.replacingOccurrences(of: "_", with: "")] = id
            }
            if let abbr = TimeZone(identifier: id)?.abbreviation()?.lowercased(), !abbr.isEmpty {
                map[abbr] = id
            }
        }

        return map
    }()

    static func resolve(_ alias: String) -> String? {
        let normalized = alias
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")

        guard !normalized.isEmpty else { return nil }

        if let mapped = aliasMap[normalized] {
            return mapped
        }

        let match = TimeZoneCatalog.filtered(normalized).first
        return match
    }
}
