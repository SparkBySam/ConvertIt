import Foundation

struct BatchRenameOptions {
    var prefix = ""
    var suffix = ""
    var pattern = "{name}"
    var find = ""
    var replace = ""
    var startNumber = 1
    var newExtension = ""
    var keepExtension = true
    var outputDirectory: URL?
    var conflictPolicy: MediaConflictPolicy = .autoRename

    func newFilename(for url: URL, index: Int) -> String {
        var baseName = url.deletingPathExtension().lastPathComponent

        if !find.isEmpty {
            baseName = baseName.replacingOccurrences(of: find, with: replace)
        }

        let number = startNumber + index
        let rendered = pattern
            .replacingOccurrences(of: "{name}", with: baseName)
            .replacingOccurrences(of: "{ext}", with: url.pathExtension.lowercased())
            .replacingOccurrences(of: "{nn}", with: String(format: "%02d", number))
            .replacingOccurrences(of: "{n}", with: String(number))

        let ext: String
        if keepExtension {
            ext = url.pathExtension
        } else if newExtension.isEmpty {
            ext = url.pathExtension
        } else {
            ext = newExtension.replacingOccurrences(of: ".", with: "")
        }

        let stem = prefix + rendered + suffix
        guard !ext.isEmpty else { return stem }
        return stem + "." + ext
    }
}

enum BatchRenameEngine {
    static func preview(options: BatchRenameOptions, files: [URL]) -> [(input: URL, output: String)] {
        files.enumerated().map { index, url in
            (url, options.newFilename(for: url, index: index))
        }
    }

    static func rename(
        files: [URL],
        options: BatchRenameOptions,
        progress: ((Int, Int, URL) -> Void)? = nil
    ) throws -> [MediaJobResult] {
        var results: [MediaJobResult] = []
        var usedNames: Set<String> = []
        let total = files.count

        for (index, url) in files.enumerated() {
            progress?(index + 1, total, url)
            let newName = options.newFilename(for: url, index: index)
            let parent = options.outputDirectory ?? url.deletingLastPathComponent()
            let destination = parent.appendingPathComponent(newName)

            if url.lastPathComponent == newName {
                results.append(MediaJobResult(input: url, status: .success(output: url)))
                continue
            }

            if usedNames.contains(newName.lowercased()) {
                results.append(MediaJobResult(
                    input: url,
                    status: .failed(message: "Duplicate name: \(newName)")
                ))
                continue
            }

            if FileManager.default.fileExists(atPath: destination.path) {
                switch options.conflictPolicy {
                case .skip:
                    results.append(MediaJobResult(
                        input: url,
                        status: .failed(message: "Skipped existing: \(newName)")
                    ))
                    continue
                case .overwrite:
                    try? FileManager.default.removeItem(at: destination)
                case .autoRename:
                    let unique = uniqueDestination(for: url, in: parent, filename: newName)
                    try performMove(from: url, to: unique)
                    usedNames.insert(unique.lastPathComponent.lowercased())
                    results.append(MediaJobResult(input: url, status: .success(output: unique)))
                    continue
                }
            }

            if options.outputDirectory != nil {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            }

            do {
                try performMove(from: url, to: destination)
                usedNames.insert(newName.lowercased())
                results.append(MediaJobResult(input: url, status: .success(output: destination)))
            } catch {
                results.append(MediaJobResult(
                    input: url,
                    status: .failed(message: error.localizedDescription)
                ))
            }
        }

        return results
    }

    static func performMove(from source: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        do {
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            try FileManager.default.copyItem(at: source, to: destination)
            try FileManager.default.removeItem(at: source)
        }
    }

    static func resolveDestination(
        directory: URL,
        filename: String,
        input: URL,
        policy: MediaConflictPolicy
    ) -> URL? {
        let requested = directory.appendingPathComponent(filename)
        switch policy {
        case .skip:
            return FileManager.default.fileExists(atPath: requested.path) ? nil : requested
        case .overwrite:
            return requested
        case .autoRename:
            return uniqueDestination(for: input, in: directory, filename: filename)
        }
    }

    static func uniqueDestination(for url: URL, in directory: URL, filename: String) -> URL {
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var candidate = directory.appendingPathComponent(filename)
        var counter = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            candidate = directory.appendingPathComponent(numbered)
            counter += 1
        }

        return candidate
    }
}
