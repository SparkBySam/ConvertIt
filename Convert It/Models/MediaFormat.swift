import UniformTypeIdentifiers

enum MediaCategory: String, CaseIterable, Identifiable {
    case image
    case video
    case audio
    case document

    var id: String { rawValue }

    var label: String {
        switch self {
        case .image: "Image"
        case .video: "Video"
        case .audio: "Audio"
        case .document: "Spreadsheet"
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .document: "tablecells"
        }
    }
}

struct MediaFormat: Identifiable, Hashable {
    let id: String
    let label: String
    let category: MediaCategory
    let fileExtension: String
    let utType: UTType?

    static let all: [MediaFormat] = [
        // Images
        .init(id: "jpg", label: "JPEG", category: .image, fileExtension: "jpg", utType: .jpeg),
        .init(id: "png", label: "PNG", category: .image, fileExtension: "png", utType: .png),
        .init(id: "heic", label: "HEIC", category: .image, fileExtension: "heic", utType: .heic),
        .init(id: "tiff", label: "TIFF", category: .image, fileExtension: "tiff", utType: .tiff),
        .init(id: "gif", label: "GIF", category: .image, fileExtension: "gif", utType: .gif),
        .init(id: "bmp", label: "BMP", category: .image, fileExtension: "bmp", utType: .bmp),
        .init(id: "webp", label: "WebP", category: .image, fileExtension: "webp", utType: .webP),
        .init(id: "ico", label: "ICO", category: .image, fileExtension: "ico", utType: nil),
        .init(id: "icns", label: "ICNS", category: .image, fileExtension: "icns", utType: UTType(filenameExtension: "icns")),
        .init(id: "pdf", label: "PDF", category: .image, fileExtension: "pdf", utType: .pdf),

        // Video
        .init(id: "mp4", label: "MP4", category: .video, fileExtension: "mp4", utType: .mpeg4Movie),
        .init(id: "mov", label: "MOV", category: .video, fileExtension: "mov", utType: .quickTimeMovie),
        .init(id: "m4v", label: "M4V", category: .video, fileExtension: "m4v", utType: UTType(filenameExtension: "m4v")),
        .init(id: "avi", label: "AVI", category: .video, fileExtension: "avi", utType: .avi),
        .init(id: "mkv", label: "MKV", category: .video, fileExtension: "mkv", utType: UTType(filenameExtension: "mkv")),
        .init(id: "webm", label: "WebM", category: .video, fileExtension: "webm", utType: UTType(filenameExtension: "webm")),
        .init(id: "wmv", label: "WMV", category: .video, fileExtension: "wmv", utType: nil),
        .init(id: "flv", label: "FLV", category: .video, fileExtension: "flv", utType: nil),
        .init(id: "mpg", label: "MPEG", category: .video, fileExtension: "mpg", utType: .mpeg),
        .init(id: "3gp", label: "3GP", category: .video, fileExtension: "3gp", utType: nil),

        // Audio
        .init(id: "mp3", label: "MP3", category: .audio, fileExtension: "mp3", utType: .mp3),
        .init(id: "m4a", label: "M4A", category: .audio, fileExtension: "m4a", utType: UTType(filenameExtension: "m4a")),
        .init(id: "aac", label: "AAC", category: .audio, fileExtension: "aac", utType: UTType(filenameExtension: "aac")),
        .init(id: "wav", label: "WAV", category: .audio, fileExtension: "wav", utType: .wav),
        .init(id: "aiff", label: "AIFF", category: .audio, fileExtension: "aiff", utType: .aiff),
        .init(id: "flac", label: "FLAC", category: .audio, fileExtension: "flac", utType: UTType(filenameExtension: "flac")),
        .init(id: "ogg", label: "OGG", category: .audio, fileExtension: "ogg", utType: UTType(filenameExtension: "ogg")),
        .init(id: "opus", label: "Opus", category: .audio, fileExtension: "opus", utType: UTType(filenameExtension: "opus")),
        .init(id: "wma", label: "WMA", category: .audio, fileExtension: "wma", utType: UTType(filenameExtension: "wma")),
        .init(id: "caf", label: "CAF", category: .audio, fileExtension: "caf", utType: UTType(filenameExtension: "caf")),

        // Spreadsheets / documents
        .init(id: "csv", label: "CSV", category: .document, fileExtension: "csv", utType: .commaSeparatedText),
        .init(id: "tsv", label: "TSV", category: .document, fileExtension: "tsv", utType: .tabSeparatedText),
        .init(id: "xlsx", label: "Excel (XLSX)", category: .document, fileExtension: "xlsx", utType: UTType(filenameExtension: "xlsx")),
    ]

    static func formats(for category: MediaCategory) -> [MediaFormat] {
        all.filter { $0.category == category }
    }

    static func detectCategory(for url: URL) -> MediaCategory? {
        if let type = UTType(filenameExtension: url.pathExtension) {
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
            if type.conforms(to: .audio) { return .audio }
            if type.conforms(to: .spreadsheet)
                || type.conforms(to: .commaSeparatedText)
                || type.conforms(to: .tabSeparatedText) {
                return .document
            }
        }
        return detectCategoryByExtension(url.pathExtension.lowercased())
    }

    static func format(forExtension ext: String) -> MediaFormat? {
        let normalized = ext.lowercased()
        return all.first { $0.fileExtension == normalized || $0.id == normalized }
    }

    private static func detectCategoryByExtension(_ ext: String) -> MediaCategory? {
        guard let format = format(forExtension: ext) else { return nil }
        return format.category
    }
}
