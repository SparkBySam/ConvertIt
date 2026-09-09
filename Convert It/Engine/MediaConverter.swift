import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MediaConversionError: LocalizedError {
    case cannotReadInput
    case cannotWriteOutput
    case unsupportedFormat
    case exportFailed(String)
    case ffmpegNotFound
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cannotReadInput: "Could not read the selected file."
        case .cannotWriteOutput: "Could not write the converted file."
        case .unsupportedFormat: "That conversion is not supported."
        case .exportFailed(let detail): detail
        case .ffmpegNotFound: "Install ffmpeg for this format (brew install ffmpeg)."
        case .cancelled: "Conversion was cancelled."
        }
    }
}

enum MediaConverter {
    struct ConversionOptions {
        var jpegQuality: Double = 0.9
        var maxDimension: Int = 0
        var outputFilenamePattern: String = "{name}.{ext}"
        var stripMetadata: Bool = false
        var bitratePreset: MediaBitratePreset = .medium
        var conflictPolicy: MediaConflictPolicy = .autoRename
    }

    static func convert(
        input: URL,
        output: URL,
        to format: MediaFormat,
        options: ConversionOptions = ConversionOptions()
    ) async throws {
        guard let category = MediaFormat.detectCategory(for: input) else {
            throw MediaConversionError.unsupportedFormat
        }
        guard category == format.category else {
            throw MediaConversionError.unsupportedFormat
        }

        switch category {
        case .image:
            if format.id == "pdf" || format.id == "icns" {
                try convertImage(input: input, output: output, format: format, options: options)
            } else if format.id == "webp" {
                try await convertImageToWebP(input: input, output: output, format: format, options: options)
            } else if format.utType != nil {
                try convertImage(input: input, output: output, format: format, options: options)
            } else {
                try await convertWithFFmpeg(input: input, output: output, format: format, options: options)
            }
        case .video, .audio:
            if canUseAVFoundation(from: input, to: format) {
                try await convertWithAVFoundation(input: input, output: output, format: format, options: options)
            } else {
                try await convertWithFFmpeg(input: input, output: output, format: format, options: options)
            }
        case .document:
            try DocumentConverter.convert(input: input, output: output, to: format)
        }
    }

    static func convertBatch(
        files: [URL],
        to format: MediaFormat,
        outputDirectory: URL,
        options: ConversionOptions = ConversionOptions(),
        isCancelled: @escaping () -> Bool = { false },
        progress: (@MainActor (Int, Int, URL) -> Void)? = nil
    ) async -> [MediaJobResult] {
        var results: [MediaJobResult] = []
        let total = files.count

        for (index, input) in files.enumerated() {
            if isCancelled() {
                results.append(MediaJobResult(
                    input: input,
                    status: .failed(message: MediaConversionError.cancelled.localizedDescription)
                ))
                continue
            }

            if Task.isCancelled {
                break
            }

            if let progress {
                await MainActor.run {
                    progress(index + 1, total, input)
                }
            }

            let filename = OutputFilenameFormatter.format(
                pattern: options.outputFilenamePattern,
                input: input,
                outputExtension: format.fileExtension
            )
            guard let destination = BatchRenameEngine.resolveDestination(
                directory: outputDirectory,
                filename: filename,
                input: input,
                policy: options.conflictPolicy
            ) else {
                results.append(MediaJobResult(
                    input: input,
                    status: .failed(message: "Skipped existing: \(filename)")
                ))
                continue
            }

            if options.conflictPolicy == .overwrite,
               FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }

            do {
                try await convert(input: input, output: destination, to: format, options: options)
                results.append(MediaJobResult(input: input, status: .success(output: destination)))
            } catch {
                cleanupFailedOutput(at: destination)
                results.append(MediaJobResult(
                    input: input,
                    status: .failed(message: friendlyErrorMessage(for: error))
                ))
            }
        }

        return results
    }

    static var isFFmpegAvailable: Bool {
        FFmpegProvisioner.isAvailable
    }

    // MARK: - Images

    private static let icnsExportSizes = [16, 32, 64, 128, 256, 512, 1024]

    private static func convertImage(
        input: URL,
        output: URL,
        format: MediaFormat,
        options: ConversionOptions
    ) throws {
        if format.id == "pdf" {
            try convertImageToPDF(input: input, output: output, options: options)
            return
        }

        if format.id == "icns" {
            try convertImageToICNS(input: input, output: output, options: options)
            return
        }

        guard let utType = format.utType ?? UTType(filenameExtension: format.fileExtension) else {
            throw MediaConversionError.unsupportedFormat
        }

        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              var image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MediaConversionError.cannotReadInput
        }

        if options.maxDimension > 0 {
            image = resizedImage(image, maxDimension: options.maxDimension) ?? image
        }

        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            throw MediaConversionError.cannotWriteOutput
        }

        var properties: [CFString: Any] = [:]
        if !options.stripMetadata {
            properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        }

        switch format.id {
        case "jpg", "heic":
            properties[kCGImageDestinationLossyCompressionQuality] = options.jpegQuality
        default:
            break
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw MediaConversionError.exportFailed("Image export failed.")
        }
    }

    private static func convertImageToWebP(
        input: URL,
        output: URL,
        format: MediaFormat,
        options: ConversionOptions
    ) async throws {
        do {
            try convertImageViaImageIOWebP(input: input, output: output, options: options)
            try validateOutputFile(at: output)
        } catch let imageIOError {
            cleanupFailedOutput(at: output)
            guard ffmpegSupportsImageEncoder("libwebp") else {
                throw imageIOError
            }
            try await convertWithFFmpeg(input: input, output: output, format: format, options: options)
        }
    }

    private static func convertImageViaImageIOWebP(
        input: URL,
        output: URL,
        options: ConversionOptions
    ) throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              var image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MediaConversionError.cannotReadInput
        }

        if options.maxDimension > 0 {
            image = resizedImage(image, maxDimension: options.maxDimension) ?? image
        }
        image = normalizedSRGBImage(image) ?? image

        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }

        let typeIdentifier = UTType.webP.identifier as CFString
        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            typeIdentifier,
            1,
            nil
        ) else {
            throw MediaConversionError.cannotWriteOutput
        }

        // WebP rejects most copied EXIF/ICC metadata from JPEG/HEIC sources.
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: options.jpegQuality,
        ]

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw MediaConversionError.exportFailed("WebP export failed.")
        }
    }

    private static func normalizedSRGBImage(_ image: CGImage) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    private static func resizedImage(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let width = image.width
        let height = image.height
        let longest = max(width, height)
        guard longest > maxDimension else { return image }

        let scale = Double(maxDimension) / Double(longest)
        let newWidth = Int(Double(width) * scale)
        let newHeight = Int(Double(height) * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }

    private static func convertImageToPDF(
        input: URL,
        output: URL,
        options: ConversionOptions
    ) throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              var image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MediaConversionError.cannotReadInput
        }

        if options.maxDimension > 0 {
            image = resizedImage(image, maxDimension: options.maxDimension) ?? image
        }

        var mediaBox = CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height))
        guard let context = CGContext(output as CFURL, mediaBox: &mediaBox, nil) else {
            throw MediaConversionError.cannotWriteOutput
        }

        context.draw(image, in: mediaBox)
    }

    private static func convertImageToICNS(
        input: URL,
        output: URL,
        options: ConversionOptions
    ) throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              var image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MediaConversionError.cannotReadInput
        }

        if options.maxDimension > 0 {
            image = resizedImage(image, maxDimension: options.maxDimension) ?? image
        }

        let typeIdentifier = UTType(filenameExtension: "icns")?.identifier ?? "com.apple.icns"
        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            typeIdentifier as CFString,
            icnsExportSizes.count,
            nil
        ) else {
            throw MediaConversionError.cannotWriteOutput
        }

        for size in icnsExportSizes {
            let scaled = resizedImage(image, maxDimension: size) ?? image
            CGImageDestinationAddImage(destination, scaled, nil)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw MediaConversionError.exportFailed("ICNS export failed.")
        }
    }

    // MARK: - AVFoundation

    private static func canUseAVFoundation(from input: URL, to format: MediaFormat) -> Bool {
        let inputExt = input.pathExtension.lowercased()
        let nativeInputs: Set<String> = ["mp4", "mov", "m4v", "m4a", "aac", "wav", "aiff", "caf", "mp3"]
        let nativeOutputs: Set<String> = ["mp4", "mov", "m4v", "m4a", "aac", "wav", "aiff", "caf"]

        return nativeInputs.contains(inputExt) && nativeOutputs.contains(format.fileExtension)
    }

    private static func convertWithAVFoundation(
        input: URL,
        output: URL,
        format: MediaFormat,
        options: ConversionOptions
    ) async throws {
        let asset = AVURLAsset(url: input)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: exportPreset(for: format)
        ) else {
            throw MediaConversionError.exportFailed("Could not create export session.")
        }

        exportSession.outputURL = output
        exportSession.outputFileType = avFileType(for: format)

        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }

        try await exportSession.export(to: output, as: avFileType(for: format))
    }

    private static func exportPreset(for format: MediaFormat) -> String {
        switch format.category {
        case .audio:
            return AVAssetExportPresetAppleM4A
        case .video:
            switch format.id {
            case "mov": return AVAssetExportPresetHighestQuality
            default: return AVAssetExportPresetHighestQuality
            }
        case .image:
            return AVAssetExportPresetHighestQuality
        case .document:
            return AVAssetExportPresetPassthrough
        }
    }

    private static func avFileType(for format: MediaFormat) -> AVFileType {
        switch format.fileExtension {
        case "mov": return .mov
        case "m4v": return .m4v
        case "m4a", "aac": return .m4a
        case "caf": return .caf
        case "wav": return .wav
        case "aiff": return .aiff
        default: return .mp4
        }
    }

    // MARK: - FFmpeg

    private static func convertWithFFmpeg(
        input: URL,
        output: URL,
        format: MediaFormat,
        options: ConversionOptions
    ) async throws {
        guard let ffmpeg = ffmpegPath() else {
            throw MediaConversionError.ffmpegNotFound
        }

        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }

        var arguments = ["-nostdin", "-y", "-i", input.path]

        switch format.category {
        case .video:
            arguments += videoFFmpegArgs(for: format, preset: options.bitratePreset)
        case .audio:
            arguments += audioFFmpegArgs(for: format, preset: options.bitratePreset)
        case .image:
            arguments += imageFFmpegArgs(for: format, options: options)
        case .document:
            throw MediaConversionError.unsupportedFormat
        }

        arguments.append(output.path)

        let exitStatus = try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpeg)
            process.arguments = arguments

            let stderr = Pipe()
            process.standardError = stderr
            process.standardOutput = FileHandle.nullDevice

            try process.run()
            process.waitUntilExit()

            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, data)
        }.value

        guard exitStatus.0 == 0 else {
            cleanupFailedOutput(at: output)
            throw MediaConversionError.exportFailed(ffmpegErrorMessage(from: exitStatus.1))
        }

        try validateOutputFile(at: output)
    }

    private static func videoFFmpegArgs(for format: MediaFormat, preset: MediaBitratePreset) -> [String] {
        let quality = preset.videoToolboxQuality
        let crf = preset.videoCRF
        switch format.id {
        case "mp4", "m4v":
            return h264VideoToolboxArgs(quality: quality, audioBitrate: preset.audioBitrate, fastStart: true)
        case "mov":
            return h264VideoToolboxArgs(quality: quality, audioBitrate: preset.audioBitrate, fastStart: false)
        case "webm":
            return [
                "-c:v", "libvpx-vp9",
                "-crf", crf,
                "-b:v", "0",
                "-cpu-used", "4",
                "-row-mt", "1",
                "-c:a", "libopus",
                "-b:a", preset.audioBitrate,
            ]
        case "avi":
            return ["-c:v", "mpeg4", "-q:v", preset == .high ? "2" : preset == .medium ? "5" : "8", "-c:a", "mp3", "-b:a", preset.audioBitrate]
        case "mkv":
            return h264VideoToolboxArgs(quality: quality, audioBitrate: preset.audioBitrate, fastStart: false)
        case "wmv":
            return ["-c:v", "wmv2", "-c:a", "wmav2", "-b:a", preset.audioBitrate]
        case "flv":
            return ["-c:v", "flv", "-c:a", "mp3", "-b:a", preset.audioBitrate]
        case "mpg":
            return ["-c:v", "mpeg2video", "-c:a", "mp2", "-b:a", preset.audioBitrate]
        case "3gp":
            return [
                "-vf", "scale=352:288:force_original_aspect_ratio=decrease,format=yuv420p",
                "-c:v", "mpeg4",
                "-q:v", preset == .high ? "3" : preset == .medium ? "5" : "8",
                "-c:a", "aac",
                "-ac", "1",
                "-ar", "44100",
                "-b:a", preset.audioBitrate,
                "-f", "3gp",
            ]
        default:
            return h264VideoToolboxArgs(quality: quality, audioBitrate: preset.audioBitrate, fastStart: false)
        }
    }

    /// H.264 via VideoToolbox — avoids GPL libx264 while staying LGPL-compliant.
    private static func h264VideoToolboxArgs(
        quality: String,
        audioBitrate: String,
        fastStart: Bool
    ) -> [String] {
        var args = ["-c:v", "h264_videotoolbox", "-q:v", quality, "-c:a", "aac", "-b:a", audioBitrate]
        if fastStart {
            args.append(contentsOf: ["-movflags", "+faststart"])
        }
        return args
    }

    private static func audioFFmpegArgs(for format: MediaFormat, preset: MediaBitratePreset) -> [String] {
        switch format.id {
        case "mp3":
            return ["-vn", "-c:a", "libmp3lame", "-q:a", preset.mp3Quality]
        case "m4a", "aac":
            return ["-vn", "-c:a", "aac", "-b:a", preset.audioBitrate]
        case "wav":
            return ["-vn", "-c:a", "pcm_s16le"]
        case "aiff":
            return ["-vn", "-c:a", "pcm_s16be"]
        case "flac":
            return ["-vn", "-c:a", "flac"]
        case "ogg":
            return ["-vn", "-c:a", "libvorbis", "-b:a", preset.audioBitrate]
        case "opus":
            return ["-vn", "-c:a", "libopus", "-b:a", preset.audioBitrate]
        case "wma":
            return ["-vn", "-c:a", "wmav2", "-b:a", preset.audioBitrate]
        case "caf":
            return ["-vn", "-c:a", "aac", "-b:a", preset.audioBitrate]
        default:
            return ["-vn", "-c:a", "aac", "-b:a", preset.audioBitrate]
        }
    }

    private static func imageFFmpegArgs(for format: MediaFormat, options: ConversionOptions) -> [String] {
        var args = ["-frames:v", "1"]

        if options.maxDimension > 0 {
            args.append(contentsOf: [
                "-vf",
                "scale='min(iw,\(options.maxDimension))':min(ih,\(options.maxDimension))':force_original_aspect_ratio=decrease",
            ])
        }

        switch format.id {
        case "webp":
            let quality = max(1, min(Int((options.jpegQuality * 100).rounded()), 100))
            args.append(contentsOf: ["-c:v", "libwebp", "-lossless", "0", "-quality", String(quality)])
        default:
            break
        }

        return args
    }

    private static var cachedFFmpegEncoders: String?

    private static func ffmpegSupportsImageEncoder(_ name: String) -> Bool {
        guard let encoders = ffmpegEncoderList() else { return false }
        return encoders.contains(" \(name) ")
    }

    private static func ffmpegEncoderList() -> String? {
        if let cachedFFmpegEncoders { return cachedFFmpegEncoders }
        guard let ffmpeg = ffmpegPath() else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = ["-hide_banner", "-encoders"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        cachedFFmpegEncoders = text
        return text
    }

    private static func ffmpegPath() -> String? {
        FFmpegProvisioner.resolveExecutablePath()
    }

    private static func cleanupFailedOutput(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func validateOutputFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MediaConversionError.cannotWriteOutput
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 else {
            cleanupFailedOutput(at: url)
            throw MediaConversionError.exportFailed("Conversion produced an empty file.")
        }
    }

    private static func ffmpegErrorMessage(from data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return "Conversion failed."
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        if let errorLine = lines.last(where: { line in
            let lower = line.lowercased()
            return lower.contains("error")
                || lower.contains("invalid")
                || lower.contains("not supported")
                || lower.contains("could not")
        }) {
            return errorLine
        }

        if let last = lines.last(where: { !$0.isEmpty }) {
            return last
        }

        return "Conversion failed."
    }

    private static func friendlyErrorMessage(for error: Error) -> String {
        guard let conversionError = error as? MediaConversionError else {
            return error.localizedDescription
        }
        return conversionError.localizedDescription ?? "Conversion failed."
    }
}
