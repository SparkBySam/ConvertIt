import SwiftUI

enum ConversionMode: String, CaseIterable, Identifiable, Codable {
    case quick
    case guided

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quick: "Quick"
        case .guided: "Guided"
        }
    }
}

enum PopoverTab: String, CaseIterable, Identifiable, Codable {
    case convert
    case media

    var id: String { rawValue }

    var label: String {
        switch self {
        case .convert: "Convert"
        case .media: "Media"
        }
    }
}

enum MediaTaskPreference: String, CaseIterable, Identifiable, Codable {
    case convert
    case rename

    var id: String { rawValue }

    var label: String {
        switch self {
        case .convert: "Convert"
        case .rename: "Rename"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum MenuBarIconStyle: String, CaseIterable, Identifiable, Codable {
    case convert
    case ruler
    case function
    case scale

    var id: String { rawValue }

    var label: String {
        switch self {
        case .convert: "Convert"
        case .ruler: "Ruler"
        case .function: "Function"
        case .scale: "Scale"
        }
    }

    var systemName: String {
        switch self {
        case .convert: "arrow.triangle.2.circlepath"
        case .ruler: "ruler"
        case .function: "function"
        case .scale: "scalemass"
        }
    }
}

@Observable
final class AppSettings {
    private enum Keys {
        static let unitMode = "defaultMode"
        static let iconStyle = "menuBarIconStyle"
        static let appearance = "appAppearance"
        static let timeUseManual = "timeUseManualTime"
        static let selectedTab = "selectedTab"
        static let mediaTask = "mediaTask"
        static let dataSizeBinary = "dataSizeBinary"
        static let globalHotkeyEnabled = "globalHotkeyEnabled"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let mediaOutputBookmark = "mediaOutputFolderBookmark"
        static let defaultImageFormat = "defaultImageFormat"
        static let defaultVideoFormat = "defaultVideoFormat"
        static let defaultAudioFormat = "defaultAudioFormat"
        static let defaultDocumentFormat = "defaultDocumentFormat"
        static let jpegQuality = "jpegQuality"
        static let jpegMaxDimension = "jpegMaxDimension"
        static let launchAtLogin = "launchAtLogin"
        static let recentListExpanded = "recentListExpanded"
        static let defaultCurrencyFrom = "defaultCurrencyFrom"
        static let defaultCurrencyTo = "defaultCurrencyTo"
        static let mediaOutputFilenamePattern = "mediaOutputFilenamePattern"
        static let renameOutputFilenamePattern = "renameOutputFilenamePattern"
        static let focusInputOnOpen = "focusInputOnOpen"
        static let copyResultOnReturn = "copyResultOnReturn"
        static let autoCopyResult = "autoCopyResult"
        static let hideDockIcon = "hideDockIcon"
        static let defaultGuidedCategory = "defaultGuidedCategory"
        static let resultPrecisionMode = "resultPrecisionMode"
        static let resultDecimalPlaces = "resultDecimalPlaces"
        static let mediaConflictPolicy = "mediaConflictPolicy"
        static let stripImageMetadata = "stripImageMetadata"
        static let mediaBitratePreset = "mediaBitratePreset"
        static let notifyOnBatchComplete = "notifyOnBatchComplete"
        static let hasDismissedWelcomeTip = "hasDismissedWelcomeTip"
    }

    var unitMode: ConversionMode {
        didSet { UserDefaults.standard.set(unitMode.rawValue, forKey: Keys.unitMode) }
    }

    var selectedTab: PopoverTab {
        didSet { UserDefaults.standard.set(selectedTab.rawValue, forKey: Keys.selectedTab) }
    }

    var mediaTask: MediaTaskPreference {
        didSet { UserDefaults.standard.set(mediaTask.rawValue, forKey: Keys.mediaTask) }
    }

    var showSettings = false

    var hasDismissedWelcomeTip = false

    func dismissWelcomeTip() {
        hasDismissedWelcomeTip = true
        UserDefaults.standard.set(true, forKey: Keys.hasDismissedWelcomeTip)
    }

    var menuBarIconStyle: MenuBarIconStyle {
        didSet { UserDefaults.standard.set(menuBarIconStyle.rawValue, forKey: Keys.iconStyle) }
    }

    var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var timeUseManualTime: Bool {
        didSet { UserDefaults.standard.set(timeUseManualTime, forKey: Keys.timeUseManual) }
    }

    var dataSizeBinary: Bool {
        didSet { UserDefaults.standard.set(dataSizeBinary, forKey: Keys.dataSizeBinary) }
    }

    var globalHotkeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(globalHotkeyEnabled, forKey: Keys.globalHotkeyEnabled)
            updateHotKeyRegistration()
        }
    }

    var globalHotkey: GlobalHotKey {
        didSet {
            UserDefaults.standard.set(Int(globalHotkey.keyCode), forKey: Keys.hotkeyKeyCode)
            UserDefaults.standard.set(Int(globalHotkey.modifiers), forKey: Keys.hotkeyModifiers)
            updateHotKeyRegistration()
        }
    }

    var defaultImageFormatID: String {
        didSet { UserDefaults.standard.set(defaultImageFormatID, forKey: Keys.defaultImageFormat) }
    }

    var defaultVideoFormatID: String {
        didSet { UserDefaults.standard.set(defaultVideoFormatID, forKey: Keys.defaultVideoFormat) }
    }

    var defaultAudioFormatID: String {
        didSet { UserDefaults.standard.set(defaultAudioFormatID, forKey: Keys.defaultAudioFormat) }
    }

    var defaultDocumentFormatID: String {
        didSet { UserDefaults.standard.set(defaultDocumentFormatID, forKey: Keys.defaultDocumentFormat) }
    }

    var jpegQuality: Double {
        didSet { UserDefaults.standard.set(jpegQuality, forKey: Keys.jpegQuality) }
    }

    var jpegMaxDimension: Int {
        didSet { UserDefaults.standard.set(jpegMaxDimension, forKey: Keys.jpegMaxDimension) }
    }

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            guard launchAtLogin != LaunchAtLogin.isEnabled else { return }
            try? LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }

    var recentListExpanded: Bool {
        didSet { UserDefaults.standard.set(recentListExpanded, forKey: Keys.recentListExpanded) }
    }

    var defaultCurrencyFrom: String {
        didSet { UserDefaults.standard.set(defaultCurrencyFrom, forKey: Keys.defaultCurrencyFrom) }
    }

    var defaultCurrencyTo: String {
        didSet { UserDefaults.standard.set(defaultCurrencyTo, forKey: Keys.defaultCurrencyTo) }
    }

    var mediaOutputFilenamePattern: String {
        didSet { UserDefaults.standard.set(mediaOutputFilenamePattern, forKey: Keys.mediaOutputFilenamePattern) }
    }

    var focusInputOnOpen: Bool {
        didSet { UserDefaults.standard.set(focusInputOnOpen, forKey: Keys.focusInputOnOpen) }
    }

    var copyResultOnReturn: Bool {
        didSet { UserDefaults.standard.set(copyResultOnReturn, forKey: Keys.copyResultOnReturn) }
    }

    var autoCopyResult: Bool {
        didSet { UserDefaults.standard.set(autoCopyResult, forKey: Keys.autoCopyResult) }
    }

    var hideDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(hideDockIcon, forKey: Keys.hideDockIcon)
            DockVisibility.apply(hidden: hideDockIcon)
        }
    }

    var defaultGuidedCategory: ConversionCategory {
        didSet { UserDefaults.standard.set(defaultGuidedCategory.rawValue, forKey: Keys.defaultGuidedCategory) }
    }

    var resultPrecisionMode: ResultPrecisionMode {
        didSet { UserDefaults.standard.set(resultPrecisionMode.rawValue, forKey: Keys.resultPrecisionMode) }
    }

    var resultDecimalPlaces: Int {
        didSet { UserDefaults.standard.set(resultDecimalPlaces, forKey: Keys.resultDecimalPlaces) }
    }

    var renameOutputFilenamePattern: String {
        didSet { UserDefaults.standard.set(renameOutputFilenamePattern, forKey: Keys.renameOutputFilenamePattern) }
    }

    var mediaConflictPolicy: MediaConflictPolicy {
        didSet { UserDefaults.standard.set(mediaConflictPolicy.rawValue, forKey: Keys.mediaConflictPolicy) }
    }

    var stripImageMetadata: Bool {
        didSet { UserDefaults.standard.set(stripImageMetadata, forKey: Keys.stripImageMetadata) }
    }

    var mediaBitratePreset: MediaBitratePreset {
        didSet { UserDefaults.standard.set(mediaBitratePreset.rawValue, forKey: Keys.mediaBitratePreset) }
    }

    var notifyOnBatchComplete: Bool {
        didSet { UserDefaults.standard.set(notifyOnBatchComplete, forKey: Keys.notifyOnBatchComplete) }
    }

    var focusQuickInputToken = UUID()

    var pendingQuickInput: String?
    var pendingImportURLs: [URL] = []
    var pendingRestoreKind: RecentConversion.RestoreKind?
    var pendingRestoreData: [String: String]?

    let recentConversions = RecentConversionStore()
    let pinnedConversions = PinnedConversionStore()
    let renamePresets = RenamePresetStore()
    let currencyRates = CurrencyRateStore()

    init() {
        let storedMode = UserDefaults.standard.string(forKey: Keys.unitMode)
            ?? UserDefaults.standard.string(forKey: "conversionMode")
        let storedIcon = UserDefaults.standard.string(forKey: Keys.iconStyle)
        let storedAppearance = UserDefaults.standard.string(forKey: Keys.appearance)

        unitMode = storedMode == "guided" ? .guided : .quick
        menuBarIconStyle = MenuBarIconStyle(rawValue: storedIcon ?? "") ?? .convert
        appearance = AppAppearance(rawValue: storedAppearance ?? "") ?? .system
        timeUseManualTime = UserDefaults.standard.bool(forKey: Keys.timeUseManual)
        selectedTab = PopoverTab(rawValue: UserDefaults.standard.string(forKey: Keys.selectedTab) ?? "") ?? .convert
        mediaTask = MediaTaskPreference(rawValue: UserDefaults.standard.string(forKey: Keys.mediaTask) ?? "") ?? .convert
        dataSizeBinary = UserDefaults.standard.bool(forKey: Keys.dataSizeBinary)
        globalHotkeyEnabled = UserDefaults.standard.object(forKey: Keys.globalHotkeyEnabled) as? Bool ?? true

        if UserDefaults.standard.object(forKey: Keys.hotkeyKeyCode) != nil {
            globalHotkey = GlobalHotKey(
                keyCode: UInt32(UserDefaults.standard.integer(forKey: Keys.hotkeyKeyCode)),
                modifiers: UInt32(UserDefaults.standard.integer(forKey: Keys.hotkeyModifiers))
            )
        } else {
            globalHotkey = .default
        }
        defaultImageFormatID = UserDefaults.standard.string(forKey: Keys.defaultImageFormat) ?? "jpg"
        defaultVideoFormatID = Self.sanitizeFormatID(
            UserDefaults.standard.string(forKey: Keys.defaultVideoFormat) ?? "mp4",
            for: .video,
            fallback: "mp4"
        )
        defaultAudioFormatID = UserDefaults.standard.string(forKey: Keys.defaultAudioFormat) ?? "mp3"
        defaultDocumentFormatID = Self.sanitizeFormatID(
            UserDefaults.standard.string(forKey: Keys.defaultDocumentFormat) ?? "csv",
            for: .document,
            fallback: "csv"
        )
        jpegQuality = UserDefaults.standard.object(forKey: Keys.jpegQuality) as? Double ?? 0.9
        jpegMaxDimension = UserDefaults.standard.integer(forKey: Keys.jpegMaxDimension)
        launchAtLogin = UserDefaults.standard.object(forKey: Keys.launchAtLogin) as? Bool ?? LaunchAtLogin.isEnabled
        recentListExpanded = UserDefaults.standard.object(forKey: Keys.recentListExpanded) as? Bool ?? true
        defaultCurrencyFrom = UserDefaults.standard.string(forKey: Keys.defaultCurrencyFrom) ?? "USD"
        defaultCurrencyTo = UserDefaults.standard.string(forKey: Keys.defaultCurrencyTo) ?? "EUR"
        mediaOutputFilenamePattern = UserDefaults.standard.string(forKey: Keys.mediaOutputFilenamePattern) ?? "{name}-converted.{ext}"
        renameOutputFilenamePattern = UserDefaults.standard.string(forKey: Keys.renameOutputFilenamePattern) ?? "{name}"
        focusInputOnOpen = UserDefaults.standard.object(forKey: Keys.focusInputOnOpen) as? Bool ?? true
        copyResultOnReturn = UserDefaults.standard.object(forKey: Keys.copyResultOnReturn) as? Bool ?? true
        autoCopyResult = UserDefaults.standard.object(forKey: Keys.autoCopyResult) as? Bool ?? false
        hideDockIcon = UserDefaults.standard.object(forKey: Keys.hideDockIcon) as? Bool ?? false
        defaultGuidedCategory = ConversionCategory(
            rawValue: UserDefaults.standard.string(forKey: Keys.defaultGuidedCategory) ?? ""
        ) ?? .temperature
        resultPrecisionMode = ResultPrecisionMode(
            rawValue: UserDefaults.standard.string(forKey: Keys.resultPrecisionMode) ?? ""
        ) ?? .automatic
        resultDecimalPlaces = UserDefaults.standard.object(forKey: Keys.resultDecimalPlaces) as? Int ?? 4
        mediaConflictPolicy = MediaConflictPolicy(
            rawValue: UserDefaults.standard.string(forKey: Keys.mediaConflictPolicy) ?? ""
        ) ?? .autoRename
        stripImageMetadata = UserDefaults.standard.object(forKey: Keys.stripImageMetadata) as? Bool ?? false
        mediaBitratePreset = MediaBitratePreset(
            rawValue: UserDefaults.standard.string(forKey: Keys.mediaBitratePreset) ?? ""
        ) ?? .medium
        notifyOnBatchComplete = UserDefaults.standard.object(forKey: Keys.notifyOnBatchComplete) as? Bool ?? true
        hasDismissedWelcomeTip = UserDefaults.standard.bool(forKey: Keys.hasDismissedWelcomeTip)
        DockVisibility.apply(hidden: hideDockIcon)
    }

    var resolvedDecimalPlaces: Int? {
        resultPrecisionMode == .fixed ? resultDecimalPlaces : nil
    }

    func defaultFormat(for category: MediaCategory) -> MediaFormat? {
        let id: String
        switch category {
        case .image: id = defaultImageFormatID
        case .video: id = defaultVideoFormatID
        case .audio: id = defaultAudioFormatID
        case .document: id = defaultDocumentFormatID
        }
        return MediaFormat.all.first { $0.id == id }
            ?? MediaFormat.formats(for: category).first
    }

    static func sanitizeFormatID(_ id: String, for category: MediaCategory, fallback: String) -> String {
        let validIDs = Set(MediaFormat.formats(for: category).map(\.id))
        return validIDs.contains(id) ? id : fallback
    }

    func saveMediaOutputFolder(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(bookmark, forKey: Keys.mediaOutputBookmark)
    }

    func resolvedMediaOutputFolder() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: Keys.mediaOutputBookmark) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale {
            saveMediaOutputFolder(url)
        }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    func updateHotKeyRegistration() {
        if globalHotkeyEnabled, globalHotkey.isValid {
            HotKeyManager.shared.register(
                keyCode: globalHotkey.keyCode,
                modifiers: globalHotkey.modifiers
            )
        } else {
            HotKeyManager.shared.unregister()
        }
    }

    func requestQuickInputFocus() {
        guard focusInputOnOpen else { return }
        focusQuickInputToken = UUID()
    }
}
