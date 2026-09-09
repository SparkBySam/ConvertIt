import Foundation

struct RecentConversion: Codable, Identifiable, Equatable {
    enum RestoreKind: String, Codable {
        case quick
        case unit
        case percentage
        case tip
        case timeZone
        case currency
    }

    let id: UUID
    let query: String
    let result: String
    let recordedAt: Date
    let restoreKind: RestoreKind?
    let restoreData: [String: String]?

    init(
        id: UUID = UUID(),
        query: String,
        result: String,
        recordedAt: Date = Date(),
        restoreKind: RestoreKind? = nil,
        restoreData: [String: String]? = nil
    ) {
        self.id = id
        self.query = query
        self.result = result
        self.recordedAt = recordedAt
        self.restoreKind = restoreKind
        self.restoreData = restoreData
    }
}

@Observable
final class RecentConversionStore {
    static let limit = 10

    private enum Keys {
        static let history = "recentConversions"
    }

    private(set) var items: [RecentConversion] = []

    init() {
        load()
    }

    func record(
        query: String,
        result: String,
        restoreKind: RecentConversion.RestoreKind? = nil,
        restoreData: [String: String]? = nil
    ) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !trimmedResult.isEmpty, trimmedResult != "—" else { return }

        if let first = items.first,
           first.query == trimmedQuery,
           first.result == trimmedResult,
           first.restoreKind == restoreKind,
           first.restoreData == restoreData {
            return
        }

        items.removeAll { $0.query == trimmedQuery && $0.result == trimmedResult }
        items.insert(
            RecentConversion(
                query: trimmedQuery,
                result: trimmedResult,
                restoreKind: restoreKind,
                restoreData: restoreData
            ),
            at: 0
        )

        if items.count > Self.limit {
            items = Array(items.prefix(Self.limit))
        }

        save()
    }

    func clear() {
        items = []
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Keys.history),
              let decoded = try? JSONDecoder().decode([RecentConversion].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Keys.history)
    }
}
