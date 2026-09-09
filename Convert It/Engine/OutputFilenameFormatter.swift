import Foundation

enum OutputFilenameFormatter {
    /// Tokens: `{name}` basename, `{ext}` output extension
    static func format(pattern: String, input: URL, outputExtension: String) -> String {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return input.deletingPathExtension().lastPathComponent + "." + outputExtension
        }

        let name = input.deletingPathExtension().lastPathComponent
        let result = trimmed
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{ext}", with: outputExtension)

        if result.contains(".") {
            return result
        }
        return result + "." + outputExtension
    }
}
