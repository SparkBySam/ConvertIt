import Foundation

enum MediaConflictPolicy: String, CaseIterable, Identifiable, Codable {
    case skip
    case overwrite
    case autoRename

    var id: String { rawValue }

    var label: String {
        switch self {
        case .skip: "Skip existing"
        case .overwrite: "Overwrite"
        case .autoRename: "Auto-rename"
        }
    }
}

enum MediaBitratePreset: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var videoCRF: String {
        switch self {
        case .low: "28"
        case .medium: "23"
        case .high: "18"
        }
    }

    /// Quality scale for h264_videotoolbox (-q:v, higher is better).
    var videoToolboxQuality: String {
        switch self {
        case .low: "35"
        case .medium: "50"
        case .high: "65"
        }
    }

    var audioBitrate: String {
        switch self {
        case .low: "128k"
        case .medium: "192k"
        case .high: "320k"
        }
    }

    var mp3Quality: String {
        switch self {
        case .low: "5"
        case .medium: "2"
        case .high: "0"
        }
    }
}

enum ResultPrecisionMode: String, CaseIterable, Identifiable, Codable {
    case automatic
    case fixed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: "Automatic"
        case .fixed: "Fixed decimals"
        }
    }
}

extension MediaFormat {
    var supportsQualitySetting: Bool {
        switch id {
        case "jpg", "heic", "webp": true
        default: false
        }
    }
}
