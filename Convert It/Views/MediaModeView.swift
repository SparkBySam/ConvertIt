import SwiftUI
import UniformTypeIdentifiers

struct MediaModeView: View {
    @Bindable var settings: AppSettings

    @State private var files: [MediaFileItem] = []
    @State private var isTargeted = false
    @State private var isWorking = false
    @State private var progressMessage = ""
    @State private var batchProgressCurrent = 0
    @State private var batchProgressTotal = 0
    @State private var errorMessage: String?
    @State private var results: [MediaJobResult] = []

    @State private var outputFormatID = ""
    @State private var ffmpegAvailable = false
    @State private var renameOptions = BatchRenameOptions()
    @State private var batchTask: Task<Void, Never>?
    @State private var isCancelled = false
    @State private var savedOutputFolder: URL?
    @State private var mediaDefaultsExpanded = false
    @State private var maxDimensionText = ""
    @State private var qualityText = ""
    @State private var presetName = ""

    private var batchSupportsQuality: Bool {
        outputFormat?.supportsQualitySetting ?? false
    }

    private var batchQualityLabel: String {
        outputFormat?.label ?? "Image"
    }

    private var convertFiles: [MediaFileItem] {
        files.filter(\.isSupportedForConversion)
    }

    private var sharedCategory: MediaCategory? {
        let categories = Set(convertFiles.compactMap(\.category))
        guard categories.count == 1, let category = categories.first else { return nil }
        return category
    }

    private var outputFormats: [MediaFormat] {
        guard let sharedCategory else { return [] }
        return MediaFormat.formats(for: sharedCategory)
    }

    private var renamePreview: [(input: URL, output: String)] {
        guard settings.mediaTask == .rename, !files.isEmpty else { return [] }
        var options = renameOptions
        options.outputDirectory = savedOutputFolder
        return BatchRenameEngine.preview(options: options, files: files.map(\.url))
    }

    private var outputFormat: MediaFormat? {
        MediaFormat.all.first { $0.id == outputFormatID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Task", selection: $settings.mediaTask) {
                ForEach(MediaTaskPreference.allCases) { mediaTask in
                    Text(mediaTask.label).tag(mediaTask)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .subtleSegmentedPicker()

            dropSection
            fileListSection

            switch settings.mediaTask {
            case .convert:
                mediaDefaultsSection
                convertSection
            case .rename:
                renameSection
            }

            statusSection
            actionSection
        }
        .onAppear {
            savedOutputFolder = settings.resolvedMediaOutputFolder()
            maxDimensionText = settings.jpegMaxDimension == 0 ? "" : String(settings.jpegMaxDimension)
            qualityText = String(Int((settings.jpegQuality * 100).rounded()))
            if renameOptions.pattern == "{name}" {
                renameOptions.pattern = settings.renameOutputFilenamePattern
            }
            renameOptions.conflictPolicy = settings.mediaConflictPolicy
            importPendingFilesIfNeeded()
            refreshFFmpegAvailability()
            syncOutputFormatIfNeeded()
        }
        .onDisappear {
            MediaFileLoader.stopAccess(for: files)
        }
        .onChange(of: settings.mediaTask) { _, _ in
            errorMessage = nil
            results = []
            if settings.mediaTask == .convert {
                syncOutputFormat()
            }
        }
        .onChange(of: files.count) { _, _ in
            deferSyncOutputFormat()
        }
        .onChange(of: settings.defaultImageFormatID) { _, _ in deferSyncOutputFormat() }
        .onChange(of: settings.defaultVideoFormatID) { _, _ in deferSyncOutputFormat() }
        .onChange(of: settings.defaultAudioFormatID) { _, _ in deferSyncOutputFormat() }
        .onChange(of: settings.defaultDocumentFormatID) { _, _ in deferSyncOutputFormat() }
    }

    private func deferSyncOutputFormat() {
        Task { @MainActor in
            syncOutputFormatIfNeeded()
        }
    }

    private func refreshFFmpegAvailability() {
        ffmpegAvailable = FFmpegProvisioner.isAvailable
    }

    private func syncOutputFormatIfNeeded() {
        guard settings.mediaTask == .convert else { return }
        syncOutputFormat()
    }

    @ViewBuilder
    private var mediaDefaultsSection: some View {
        DisclosureGroup(isExpanded: $mediaDefaultsExpanded) {
            VStack(alignment: .leading, spacing: UIStyles.mediaDefaultRowSpacing) {
                mediaDefaultRow("Default image format") {
                    mediaFormatPicker(
                        formats: MediaFormat.formats(for: .image),
                        selection: $settings.defaultImageFormatID
                    )
                }

                mediaDefaultRow("Default video format") {
                    mediaFormatPicker(
                        formats: MediaFormat.formats(for: .video),
                        selection: $settings.defaultVideoFormatID
                    )
                }

                mediaDefaultRow("Default audio format") {
                    mediaFormatPicker(
                        formats: MediaFormat.formats(for: .audio),
                        selection: $settings.defaultAudioFormatID
                    )
                }

                mediaDefaultRow("Default spreadsheet format") {
                    mediaFormatPicker(
                        formats: MediaFormat.formats(for: .document),
                        selection: $settings.defaultDocumentFormatID
                    )
                }

                mediaDefaultRow("Max image dimension") {
                    HStack(spacing: 8) {
                        TextField("0 = original", text: $maxDimensionText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 100)
                            .onChange(of: maxDimensionText) { _, newValue in
                                let digits = newValue.filter(\.isNumber)
                                settings.jpegMaxDimension = Int(digits) ?? 0
                            }
                        Text("px")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Convert output pattern")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        FilenamePatternHelpButton(mode: .convert)
                    }
                    TextField("{name}-converted.{ext}", text: $settings.mediaOutputFilenamePattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                outputFolderRow
            }
            .padding(.top, 6)
        } label: {
            Text("Defaults")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var outputFolderRow: some View {
        if let folder = savedOutputFolder {
            mediaDefaultRow("Output folder") {
                HStack {
                    Text(folder.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Change…") {
                        pickOutputFolder()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        } else {
            Button("Choose output folder…") {
                pickOutputFolder()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private func renamePreviewLabel(_ filename: String) -> String {
        if let folder = savedOutputFolder {
            return folder.lastPathComponent + "/" + filename
        }
        return filename
    }

    private func pickOutputFolder() {
        if let url = chooseOutputDirectory(forcePrompt: true) {
            savedOutputFolder = url
            settings.saveMediaOutputFolder(url)
        }
    }

    private func mediaDefaultRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            content()
        }
    }

    private func mediaFormatPicker(formats: [MediaFormat], selection: Binding<String>) -> some View {
        Picker("Format", selection: selection) {
            ForEach(formats) { format in
                Text(format.label).tag(format.id)
            }
        }
        .labelsHidden()
    }

    private func importPendingFilesIfNeeded() {
        guard !settings.pendingImportURLs.isEmpty else { return }
        settings.selectedTab = .media
        addFiles(settings.pendingImportURLs)
        settings.pendingImportURLs = []
    }

    @ViewBuilder
    private var dropSection: some View {
        DropZoneView(isTargeted: $isTargeted) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Drop files here")
                    .font(.subheadline)
                Text(settings.mediaTask == .convert ? "Images, video, audio, or spreadsheets" : "Any files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Choose Files…") {
                    chooseInputFiles()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            Task {
                let urls = await DropURLLoader.load(from: providers)
                addFiles(urls)
            }
            return true
        }
    }

    @ViewBuilder
    private var fileListSection: some View {
        if !files.isEmpty {
            HStack {
                Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    clearFiles()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            VStack(spacing: 4) {
                ForEach(files) { file in
                    HStack(spacing: 8) {
                        if let category = file.category {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                        } else {
                            Image(systemName: "doc")
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                        }
                        Text(file.filename)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            removeFile(file)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var convertSection: some View {
        if !convertFiles.isEmpty {
            if sharedCategory == nil {
                Text("All files must be the same type (image, video, audio, or spreadsheet).")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !outputFormats.isEmpty {
                mediaDefaultRow("Output format for this batch") {
                    Picker("Output format", selection: $outputFormatID) {
                        ForEach(outputFormats) { format in
                            Text(format.label).tag(format.id)
                        }
                    }
                    .labelsHidden()
                    .onAppear {
                        syncOutputFormatIfNeeded()
                    }
                }
            }
        }

        if settings.mediaTask == .convert, !ffmpegAvailable {
            Text("Video and audio conversion requires FFmpeg, which is not available in this installation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var renameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            outputFolderRow

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Rename pattern")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    FilenamePatternHelpButton(mode: .rename)
                }
                TextField("{name}", text: $settings.renameOutputFilenamePattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onChange(of: settings.renameOutputFilenamePattern) { _, newValue in
                        renameOptions.pattern = newValue
                    }
            }

            if !settings.renamePresets.presets.isEmpty || !files.isEmpty {
                HStack(spacing: 8) {
                    if !settings.renamePresets.presets.isEmpty {
                        Menu("Load preset") {
                            ForEach(settings.renamePresets.presets) { preset in
                                Button(preset.name) {
                                    renameOptions = preset.options
                                    settings.renameOutputFilenamePattern = preset.pattern
                                }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .font(.caption)
                    }

                    if !files.isEmpty {
                        TextField("Preset name", text: $presetName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button("Save") {
                            let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            settings.renamePresets.save(renameOptions, name: name)
                            presetName = ""
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }

            if !files.isEmpty {
                HStack {
                    TextField("Prefix", text: $renameOptions.prefix)
                    TextField("Suffix", text: $renameOptions.suffix)
                }
                .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Pattern")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        FilenamePatternHelpButton(mode: .rename)
                    }
                    TextField("{name}-{nn}", text: $renameOptions.pattern)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    TextField("Find", text: $renameOptions.find)
                    TextField("Replace", text: $renameOptions.replace)
                }
                .textFieldStyle(.roundedBorder)

                Stepper("Start number: \(renameOptions.startNumber)", value: $renameOptions.startNumber, in: 0...9999)

                Toggle("Keep original extension", isOn: $renameOptions.keepExtension)
                    .toggleStyle(.checkbox)

                if !renameOptions.keepExtension {
                    TextField("New extension", text: $renameOptions.newExtension)
                        .textFieldStyle(.roundedBorder)
                }

                if !renamePreview.isEmpty {
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(renamePreview.prefix(5), id: \.input) { item in
                            HStack(spacing: 4) {
                                Text(item.input.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                Text(renamePreviewLabel(item.output))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .font(.caption2)
                        }
                        if renamePreview.count > 5 {
                            Text("+ \(renamePreview.count - 5) more")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if isWorking {
            VStack(alignment: .leading, spacing: 8) {
                if batchProgressTotal > 0 {
                    ProgressView(value: Double(batchProgressCurrent), total: Double(batchProgressTotal)) {
                        Text(progressMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .progressViewStyle(.linear)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(progressMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                if settings.mediaTask == .convert {
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            isCancelled = true
                            batchTask?.cancel()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
        }

        if let errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
        }

        if !results.isEmpty {
            let succeeded = results.filter {
                if case .success = $0.status { return true }
                return false
            }.count
            let failed = results.count - succeeded

            VStack(alignment: .leading, spacing: 6) {
                Text("Done — \(succeeded) succeeded\(failed > 0 ? ", \(failed) failed" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(results.prefix(4)) { result in
                    HStack(spacing: 6) {
                        switch result.status {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        case .pending:
                            EmptyView()
                        }
                        Text(result.input.lastPathComponent)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if case .success = result.status {
                            Image(systemName: "arrow.up.doc")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .help("Drag to Finder")
                        }
                    }
                    .draggableFile(outputURL(from: result))
                }

                if results.count > 4 {
                    Text("+ \(results.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let folder = outputFolder(from: results) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 10) {
            if settings.mediaTask == .convert, batchSupportsQuality {
                batchQualityControl
            }

            Button {
                batchTask?.cancel()
                isCancelled = false
                batchTask = Task {
                    switch settings.mediaTask {
                    case .convert:
                        await convertFilesBatch()
                    case .rename:
                        await renameFilesBatch()
                    }
                }
            } label: {
                Text(settings.mediaTask == .convert ? "Convert \(convertFiles.count) File\(convertFiles.count == 1 ? "" : "s")" : "Rename \(files.count) File\(files.count == 1 ? "" : "s")")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isActionDisabled)
        }
    }

    private var batchQualityControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(batchQualityLabel) quality")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Slider(value: $settings.jpegQuality, in: 0.5...1.0)
                    .onChange(of: settings.jpegQuality) { _, newValue in
                        let text = String(Int((newValue * 100).rounded()))
                        if qualityText != text {
                            qualityText = text
                        }
                    }
                TextField("90", text: $qualityText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 44)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: qualityText) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue {
                            qualityText = digits
                            return
                        }
                        guard let value = Int(digits), (50...100).contains(value) else { return }
                        let normalized = Double(value) / 100.0
                        if settings.jpegQuality != normalized {
                            settings.jpegQuality = normalized
                        }
                    }
                Text("%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isActionDisabled: Bool {
        if isWorking { return true }
        switch settings.mediaTask {
        case .convert:
            return convertFiles.isEmpty || outputFormatID.isEmpty || sharedCategory == nil
        case .rename:
            return files.isEmpty
        }
    }

    private var allowedMediaTypes: [UTType] {
        var types: [UTType] = [
            .image, .movie, .video, .audio, .mpeg4Movie, .quickTimeMovie, .mp3, .wav, .aiff, .mpeg,
            .commaSeparatedText, .tabSeparatedText, .spreadsheet, .data
        ]
        for ext in ["icns", "xlsx", "csv", "tsv"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }

    private func addFiles(_ urls: [URL]) {
        errorMessage = nil
        results = []

        let filtered: [URL]
        if settings.mediaTask == .convert {
            filtered = urls.filter { MediaFormat.detectCategory(for: $0) != nil }
            if filtered.count < urls.count {
                errorMessage = "Skipped \(urls.count - filtered.count) unsupported file\(urls.count - filtered.count == 1 ? "" : "s")."
            }
        } else {
            filtered = urls.filter { !$0.hasDirectoryPath }
        }

        let newItems = MediaFileLoader.items(from: filtered)
        for item in newItems where !files.contains(where: { $0.url.path == item.url.path }) {
            files.append(item)
        }
        syncOutputFormat()
    }

    private func removeFile(_ file: MediaFileItem) {
        if file.accessActive {
            file.url.stopAccessingSecurityScopedResource()
        }
        files.removeAll { $0.id == file.id }
    }

    private func clearFiles() {
        MediaFileLoader.stopAccess(for: files)
        files = []
        results = []
        errorMessage = nil
    }

    private func syncOutputFormat() {
        guard let sharedCategory else {
            if !outputFormatID.isEmpty {
                outputFormatID = ""
            }
            return
        }

        let formats = MediaFormat.formats(for: sharedCategory)
        let validIDs = Set(formats.map(\.id))
        if validIDs.contains(outputFormatID) { return }

        outputFormatID = settings.defaultFormat(for: sharedCategory)?.id ?? formats.first?.id ?? ""
    }

    @MainActor
    private func convertFilesBatch() async {
        guard let outputFormat else { return }
        let inputs = convertFiles.map(\.url)
        guard !inputs.isEmpty, sharedCategory != nil else { return }

        guard let outputDirectory = chooseOutputDirectory(forcePrompt: savedOutputFolder == nil) else { return }
        savedOutputFolder = outputDirectory
        settings.saveMediaOutputFolder(outputDirectory)

        errorMessage = nil
        results = []
        isWorking = true
        isCancelled = false
        batchProgressTotal = inputs.count
        batchProgressCurrent = 0

        let options = MediaConverter.ConversionOptions(
            jpegQuality: settings.jpegQuality,
            maxDimension: settings.jpegMaxDimension,
            outputFilenamePattern: settings.mediaOutputFilenamePattern,
            stripMetadata: settings.stripImageMetadata,
            bitratePreset: settings.mediaBitratePreset,
            conflictPolicy: settings.mediaConflictPolicy
        )

        results = await MediaConverter.convertBatch(
            files: inputs,
            to: outputFormat,
            outputDirectory: outputDirectory,
            options: options,
            isCancelled: { isCancelled }
        ) { current, total, url in
            batchProgressCurrent = current
            batchProgressTotal = total
            progressMessage = "Converting \(current) of \(total): \(url.lastPathComponent)"
        }

        isWorking = false
        progressMessage = ""
        batchProgressCurrent = 0
        batchProgressTotal = 0
        batchTask = nil
        notifyBatchCompleteIfNeeded(task: "Convert", results: results)
    }

    @MainActor
    private func renameFilesBatch() async {
        let inputs = files.map(\.url)
        guard !inputs.isEmpty else { return }

        errorMessage = nil
        results = []
        isWorking = true
        batchProgressTotal = inputs.count
        batchProgressCurrent = 0
        progressMessage = "Renaming 0 of \(inputs.count)…"

        do {
            var options = renameOptions
            options.outputDirectory = savedOutputFolder
            options.conflictPolicy = settings.mediaConflictPolicy
            results = try BatchRenameEngine.rename(files: inputs, options: options) { current, total, url in
                batchProgressCurrent = current
                batchProgressTotal = total
                progressMessage = "Renaming \(current) of \(total): \(url.lastPathComponent)"
            }
            MediaFileLoader.stopAccess(for: files)
            files = MediaFileLoader.items(from: results.compactMap { result in
                if case .success(let output) = result.status { return output }
                return nil
            })
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
        progressMessage = ""
        batchProgressCurrent = 0
        batchProgressTotal = 0
        notifyBatchCompleteIfNeeded(task: "Rename", results: results)
    }

    private func notifyBatchCompleteIfNeeded(task: String, results: [MediaJobResult]) {
        guard settings.notifyOnBatchComplete, !StatusItemController.shared.isPopoverShown else { return }
        let succeeded = results.filter {
            if case .success = $0.status { return true }
            return false
        }.count
        let failed = results.count - succeeded
        BatchNotifier.notifyBatchComplete(task: task, succeeded: succeeded, failed: failed)
    }

    private func chooseInputFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose Files"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        if settings.mediaTask == .convert {
            panel.allowedContentTypes = allowedMediaTypes
        }

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }

        settings.pendingImportURLs = panel.urls
        settings.selectedTab = .media

        if StatusItemController.shared.isPopoverShown {
            importPendingFilesIfNeeded()
        } else {
            StatusItemController.shared.showPopover()
        }
    }

    private func chooseOutputDirectory(forcePrompt: Bool) -> URL? {
        if !forcePrompt, let savedOutputFolder {
            return savedOutputFolder
        }

        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if let savedOutputFolder {
            panel.directoryURL = savedOutputFolder
        }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url
    }

    private func outputURL(from result: MediaJobResult) -> URL? {
        if case .success(let url) = result.status { return url }
        return nil
    }

    private func outputFolder(from results: [MediaJobResult]) -> URL? {
        for result in results {
            if case .success(let output) = result.status {
                return output.deletingLastPathComponent()
            }
        }
        return nil
    }
}

private struct FilenamePatternHelpButton: View {
    enum Mode {
        case convert
        case rename
    }

    var mode: Mode = .rename
    @State private var showHelp = false

    var body: some View {
        Button {
            showHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .help("Pattern token help")
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pattern tokens")
                    .font(.caption)
                    .fontWeight(.semibold)

                tokenRow("{name}", "Original filename without extension")
                tokenRow("{ext}", mode == .convert ? "Output file extension" : "File extension")

                if mode == .rename {
                    tokenRow("{n}", "Sequence number (1, 2, 3…)")
                    tokenRow("{nn}", "Padded number (01, 02, 03…)")
                }

                Text(exampleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(width: 260)
        }
    }

    private var exampleText: String {
        switch mode {
        case .convert:
            "Example: {name}-converted.{ext} → photo-converted.jpg"
        case .rename:
            "Example: {name}-{nn} → photo-01.jpg"
        }
    }

    private func tokenRow(_ token: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(token)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .leading)
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    MediaModeView(settings: AppSettings())
        .padding()
        .frame(width: 360)
}
