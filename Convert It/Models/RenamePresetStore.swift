import Foundation

struct RenamePreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var prefix: String
    var suffix: String
    var pattern: String
    var find: String
    var replace: String
    var startNumber: Int
    var newExtension: String
    var keepExtension: Bool

    init(
        id: UUID = UUID(),
        name: String,
        options: BatchRenameOptions
    ) {
        self.id = id
        self.name = name
        self.prefix = options.prefix
        self.suffix = options.suffix
        self.pattern = options.pattern
        self.find = options.find
        self.replace = options.replace
        self.startNumber = options.startNumber
        self.newExtension = options.newExtension
        self.keepExtension = options.keepExtension
    }

    var options: BatchRenameOptions {
        var options = BatchRenameOptions()
        options.prefix = prefix
        options.suffix = suffix
        options.pattern = pattern
        options.find = find
        options.replace = replace
        options.startNumber = startNumber
        options.newExtension = newExtension
        options.keepExtension = keepExtension
        return options
    }
}

@Observable
final class RenamePresetStore {
    private enum Keys {
        static let presets = "renamePresets"
    }

    private(set) var presets: [RenamePreset] = []

    init() {
        load()
    }

    func save(_ options: BatchRenameOptions, name: String) {
        let preset = RenamePreset(name: name, options: options)
        presets.insert(preset, at: 0)
        if presets.count > 10 {
            presets = Array(presets.prefix(10))
        }
        persist()
    }

    func remove(_ preset: RenamePreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Keys.presets),
              let decoded = try? JSONDecoder().decode([RenamePreset].self, from: data) else {
            return
        }
        presets = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: Keys.presets)
    }
}
