import AppKit

enum DockVisibility {
    static func apply(hidden: Bool) {
        let policy: NSApplication.ActivationPolicy = hidden ? .accessory : .regular
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }
}
