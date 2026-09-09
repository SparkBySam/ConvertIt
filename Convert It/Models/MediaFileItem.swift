import Foundation

struct MediaFileItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let category: MediaCategory?
    var accessActive: Bool = false

    var filename: String { url.lastPathComponent }

    var isSupportedForConversion: Bool { category != nil }

    static func == (lhs: MediaFileItem, rhs: MediaFileItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum MediaJobStatus: Equatable {
    case pending
    case success(output: URL)
    case failed(message: String)
}

struct MediaJobResult: Identifiable {
    let id = UUID()
    let input: URL
    let status: MediaJobStatus
}

enum MediaFileLoader {
    static func items(from urls: [URL]) -> [MediaFileItem] {
        urls.reduce(into: []) { result, url in
            let normalized = url.standardizedFileURL
            guard !result.contains(where: { $0.url.path == normalized.path }) else { return }

            let accessActive = normalized.startAccessingSecurityScopedResource()
            let category = MediaFormat.detectCategory(for: normalized)
            result.append(MediaFileItem(url: normalized, category: category, accessActive: accessActive))
        }
    }

    static func stopAccess(for items: [MediaFileItem]) {
        for item in items where item.accessActive {
            item.url.stopAccessingSecurityScopedResource()
        }
    }
}
