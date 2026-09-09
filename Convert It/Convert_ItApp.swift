import SwiftUI

@MainActor
enum AppController {
    static let settings = AppSettings()
}

@main
struct Convert_ItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .onChange(of: AppController.settings.menuBarIconStyle) { _, newStyle in
            StatusItemController.shared.updateIcon(newStyle)
        }
    }

    init() {
        FFmpegProvisioner.prepareBundledCopyIfNeeded()
    }
}
