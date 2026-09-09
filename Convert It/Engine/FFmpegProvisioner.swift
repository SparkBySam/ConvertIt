import Foundation

enum FFmpegProvisioner {
    private static let bundledName = "ffmpeg"
    private static var cachedAvailability: Bool?
    private static var cachedAvailabilityPath: String?

    static var isAvailable: Bool {
        guard let bundled = bundledResourcePath() else {
            cachedAvailability = false
            cachedAvailabilityPath = nil
            return false
        }

        if cachedAvailabilityPath == bundled, let cachedAvailability {
            return cachedAvailability
        }

        let available = isLikelyRunnable(at: bundled)
        cachedAvailabilityPath = bundled
        cachedAvailability = available
        return available
    }

    static func resolveExecutablePath() -> String? {
        guard let bundled = bundledResourcePath(), isLikelyRunnable(at: bundled) else {
            return nil
        }
        return bundled
    }

    /// Ensures bundled ffmpeg is present. Dylibs are bundled in Contents/Frameworks at build time.
    static func prepareBundledCopyIfNeeded() {
        _ = bundledResourcePath()
    }

    /// Loads ffmpeg and dylibs once so the first conversion doesn't hitch the UI.
    static func warmUp() {
        Task.detached(priority: .utility) {
            guard let path = resolveExecutablePath() else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["-nostdin", "-version"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    static func invalidateAvailabilityCache() {
        cachedAvailability = nil
        cachedAvailabilityPath = nil
    }

    private static func isLikelyRunnable(at path: String) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else { return false }
        if FFmpegCompliance.isBundledBuildTrusted() {
            return true
        }
        return FFmpegCompliance.isBinaryCompliantFromStaticScan(at: path)
    }

    private static func bundledResourcePath() -> String? {
        bundledResourceURL()?.path
    }

    private static func bundledResourceURL() -> URL? {
        if let url = Bundle.main.url(forResource: bundledName, withExtension: "") {
            return url
        }
        if let url = Bundle.main.url(forResource: bundledName, withExtension: nil) {
            return url
        }
        if let resourcePath = Bundle.main.resourcePath {
            let direct = URL(fileURLWithPath: resourcePath).appendingPathComponent(bundledName)
            if FileManager.default.fileExists(atPath: direct.path) {
                return direct
            }
        }
        return nil
    }
}
