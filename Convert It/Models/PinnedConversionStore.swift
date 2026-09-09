import Foundation

struct PinnedConversion: Codable, Identifiable, Equatable {
    let id: UUID
    let label: String
    let restoreKind: RecentConversion.RestoreKind
    let restoreData: [String: String]

    init(
        id: UUID = UUID(),
        label: String,
        restoreKind: RecentConversion.RestoreKind,
        restoreData: [String: String]
    ) {
        self.id = id
        self.label = label
        self.restoreKind = restoreKind
        self.restoreData = restoreData
    }
}

@Observable
final class PinnedConversionStore {
    static let limit = 5

    private enum Keys {
        static let pins = "pinnedConversions"
    }

    private(set) var items: [PinnedConversion] = []

    init() {
        load()
    }

    func pin(label: String, restoreKind: RecentConversion.RestoreKind, restoreData: [String: String]) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        items.removeAll { $0.label == trimmed }
        items.insert(PinnedConversion(label: trimmed, restoreKind: restoreKind, restoreData: restoreData), at: 0)

        if items.count > Self.limit {
            items = Array(items.prefix(Self.limit))
        }
        save()
    }

    func unpin(_ item: PinnedConversion) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func exportJSON() -> Data? {
        try? JSONEncoder().encode(items)
    }

    func importJSON(_ data: Data, merge: Bool = false) throws {
        let decoded = try JSONDecoder().decode([PinnedConversion].self, from: data)
        if merge {
            for item in decoded.reversed() {
                pin(label: item.label, restoreKind: item.restoreKind, restoreData: item.restoreData)
            }
        } else {
            items = Array(decoded.prefix(Self.limit))
            save()
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Keys.pins),
              let decoded = try? JSONDecoder().decode([PinnedConversion].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Keys.pins)
    }
}
