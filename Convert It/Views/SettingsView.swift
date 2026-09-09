import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var pinImportError: String?
    @State private var showAbout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.headline)

                settingRow("Unit mode") {
                    Picker("Unit mode", selection: $settings.unitMode) {
                        ForEach(ConversionMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .subtleSegmentedPicker()
                }

                settingRow("Appearance") {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .subtleSegmentedPicker()
                }

                settingRow("Menu bar icon") {
                    Picker("Menu bar icon", selection: $settings.menuBarIconStyle) {
                        ForEach(MenuBarIconStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .labelsHidden()
                }

                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .toggleStyle(.checkbox)

                Toggle("Focus input when opening", isOn: $settings.focusInputOnOpen)
                    .toggleStyle(.checkbox)

                Toggle("Hide Dock icon", isOn: $settings.hideDockIcon)
                    .toggleStyle(.checkbox)

                Toggle("Copy result on Return", isOn: $settings.copyResultOnReturn)
                    .toggleStyle(.checkbox)

                Toggle("Auto-copy when result changes", isOn: $settings.autoCopyResult)
                    .toggleStyle(.checkbox)

                settingRow("Default guided category") {
                    Picker("Category", selection: $settings.defaultGuidedCategory) {
                        ForEach(ConversionCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    .labelsHidden()
                }

                settingRow("Result precision") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Precision", selection: $settings.resultPrecisionMode) {
                            ForEach(ResultPrecisionMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .subtleSegmentedPicker()

                        if settings.resultPrecisionMode == .fixed {
                            Stepper("Decimal places: \(settings.resultDecimalPlaces)", value: $settings.resultDecimalPlaces, in: 0...10)
                                .font(.caption)
                        }
                    }
                }

                settingRow("Data size units") {
                    Picker("Data size units", selection: $settings.dataSizeBinary) {
                        Text("Decimal (KB)").tag(false)
                        Text("Binary (KiB)").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .subtleSegmentedPicker()
                }

                settingRow("Global hotkey") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enabled", isOn: $settings.globalHotkeyEnabled)
                            .toggleStyle(.checkbox)

                        if settings.globalHotkeyEnabled {
                            HotKeyRecorderView(hotkey: $settings.globalHotkey)
                            Text("Include ⌘, ⌥, ⌃, or ⇧. Esc cancels recording.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                SettingsSectionHeader(title: "Currency defaults")

                settingRow("Default from") {
                    currencyPicker(selection: $settings.defaultCurrencyFrom)
                }

                settingRow("Default to") {
                    currencyPicker(selection: $settings.defaultCurrencyTo)
                }

                Divider()
                    .padding(.vertical, 4)

                SettingsSectionHeader(title: "Pinned conversions")

                HStack {
                    Button("Export…") { exportPins() }
                    Button("Import…") { importPins() }
                }
                .buttonStyle(.borderless)
                .font(.caption)

                if let pinImportError {
                    Text(pinImportError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Divider()
                    .padding(.vertical, 4)

                SettingsSectionHeader(title: "Media defaults")

                settingRow("File conflicts") {
                    Picker("Conflicts", selection: $settings.mediaConflictPolicy) {
                        ForEach(MediaConflictPolicy.allCases) { policy in
                            Text(policy.label).tag(policy)
                        }
                    }
                    .labelsHidden()
                }

                Toggle("Strip image metadata (EXIF)", isOn: $settings.stripImageMetadata)
                    .toggleStyle(.checkbox)

                settingRow("Video/audio quality") {
                    Picker("Bitrate", selection: $settings.mediaBitratePreset) {
                        ForEach(MediaBitratePreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .subtleSegmentedPicker()
                }

                Toggle("Notify when batch completes", isOn: $settings.notifyOnBatchComplete)
                    .toggleStyle(.checkbox)

                Divider()
                    .padding(.vertical, 6)

                Button("About ConvertIt") {
                    showAbout = true
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)

                Button("Terms of Use & licenses") {
                    LegalLinks.openTermsOfUse()
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 300)
        .frame(maxHeight: 560)
        .aboutPanel(isPresented: $showAbout)
    }

    private func currencyPicker(selection: Binding<String>) -> some View {
        Picker("Currency", selection: selection) {
            ForEach(CurrencyRateStore.supportedCodes, id: \.self) { code in
                Text(code).tag(code)
            }
        }
        .labelsHidden()
    }

    private func exportPins() {
        guard let data = settings.pinnedConversions.exportJSON() else { return }
        let panel = NSSavePanel()
        panel.title = "Export Pinned Conversions"
        panel.nameFieldStringValue = "convertit-pins.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }

    private func importPins() {
        let panel = NSOpenPanel()
        panel.title = "Import Pinned Conversions"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            try settings.pinnedConversions.importJSON(data, merge: true)
            pinImportError = nil
        } catch {
            pinImportError = error.localizedDescription
        }
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings())
        .padding()
}
