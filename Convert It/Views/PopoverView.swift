import SwiftUI

private enum PopoverLayout {
    static let width: CGFloat = 380
}

struct PopoverView: View {
    @Bindable var settings: AppSettings
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            if !settings.hasDismissedWelcomeTip {
                welcomeTip
                Divider()
            }
            tabBar
            Divider()
            ScrollView {
                tabContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: UIStyles.popoverMaxContentHeight)
            .padding(14)
            Divider()
            footer
        }
        .frame(width: PopoverLayout.width)
        .fixedSize(horizontal: true, vertical: true)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .convertItQuickInput)) { notification in
            if let text = notification.object as? String {
                settings.pendingQuickInput = text
                settings.selectedTab = .convert
                settings.unitMode = .quick
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .convertItImportFiles)) { notification in
            if let urls = notification.object as? [URL] {
                settings.pendingImportURLs = urls
                settings.selectedTab = .media
            }
        }
        .onExitCommand {
            onClose?()
        }
    }

    private var header: some View {
        HStack {
            Text("ConvertIt")
                .font(.headline)
            Spacer()
            Button {
                settings.showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .popover(isPresented: $settings.showSettings, arrowEdge: .top) {
                SettingsView(settings: settings)
                    .padding(16)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var welcomeTip: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome to ConvertIt")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Press \(settings.globalHotkey.displayString) anytime to open or close this window.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                settings.dismissWelcomeTip()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }

    private var tabBar: some View {
        Picker("Tab", selection: $settings.selectedTab) {
            ForEach(PopoverTab.allCases) { tab in
                Text(tab.label).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .subtleSegmentedPicker()
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            if settings.globalHotkeyEnabled {
                Text(settings.globalHotkey.displayString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Quit ConvertIt") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption2)
            .fontWeight(.regular)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var tabContent: some View {
        ZStack(alignment: .topLeading) {
            convertTabContent
                .tabStackVisible(settings.selectedTab == .convert)

            MediaModeView(settings: settings)
                .tabStackVisible(settings.selectedTab == .media)
        }
    }

    private var convertTabContent: some View {
        ZStack(alignment: .topLeading) {
            QuickModeView(settings: settings)
                .tabStackVisible(settings.unitMode == .quick)

            GuidedModeView(settings: settings)
                .tabStackVisible(settings.unitMode == .guided)
        }
    }
}

#Preview {
    PopoverView(settings: AppSettings())
}
