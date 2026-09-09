import Foundation

enum FFmpegCompliance {
    /// Host the matching FFmpeg source tarball on the same site as app downloads.
    static let sourceDownloadURL = URL(string: "https://convertitapp.com/legal/ffmpeg-source")!
    static let projectURL = URL(string: "https://ffmpeg.org")!
    static let lgplURL = URL(string: "https://convertitapp.com/legal/lgpl-2.1/")!

    static let aboutNotice = """
    This software uses libraries from the FFmpeg project under the LGPLv2.1.
    """

    static let bundledNotice = """
    This software uses code of FFmpeg (ffmpeg.org) licensed under the LGPLv2.1. \
    Corresponding source code is available at convertitapp.com/legal/ffmpeg-source.
    """

    /// Returns false when the binary was built with --enable-gpl or --enable-nonfree.
    static func isBinaryCompliant(at path: String) -> Bool {
        guard let configuration = configurationLine(for: path) else {
            return isBinaryCompliantFromStaticScan(at: path)
        }
        return isCompliantConfiguration(configuration)
    }

    static func isCompliantConfiguration(_ configuration: String) -> Bool {
        let lower = configuration.lowercased()
        if lower.contains("--enable-gpl") { return false }
        if lower.contains("--enable-nonfree") { return false }
        return true
    }

    static func configurationLine(for path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        return output
            .split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix("configuration:") }
            .map(String.init)
    }

    /// Reads the embedded configuration string without executing the binary.
    static func isBinaryCompliantFromStaticScan(at path: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead, .uncached]) else {
            return false
        }

        guard let marker = "configuration: ".data(using: .utf8),
              let range = data.range(of: marker) else {
            return false
        }

        let end = min(range.upperBound + 2048, data.count)
        let snippet = data[range.lowerBound..<end]
        guard let text = String(data: snippet, encoding: .utf8)
            ?? String(data: snippet, encoding: .ascii) else {
            return false
        }

        return isCompliantConfiguration(text)
    }

    static func bundledBuildInfo() -> String? {
        guard let url = Bundle.main.url(forResource: "ffmpeg-build-info", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    static func isBundledBuildTrusted() -> Bool {
        guard let info = bundledBuildInfo()?.lowercased() else { return false }
        return !info.contains("--enable-gpl") && !info.contains("--enable-nonfree")
    }
}
