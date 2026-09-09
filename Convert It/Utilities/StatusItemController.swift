import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settings: AppSettings?
    private var isInstalled = false
    private var hostingController: NSHostingController<AnyView>?
    private var outsideClickMonitors: [Any] = []

    private override init() {
        super.init()
    }

    func install(settings: AppSettings) {
        self.settings = settings
        guard !isInstalled else { return }
        isInstalled = true

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: settings.menuBarIconStyle.systemName,
            accessibilityDescription: "ConvertIt"
        )
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        HotKeyManager.shared.onHotKey = { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.togglePopover()
        }

        if settings.globalHotkeyEnabled {
            settings.updateHotKeyRegistration()
        }

        Task { await settings.currencyRates.refreshIfNeeded() }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenPopover),
            name: .convertItOpenPopover,
            object: nil
        )
    }

    func updateIcon(_ style: MenuBarIconStyle) {
        statusItem?.button?.image = NSImage(
            systemSymbolName: style.systemName,
            accessibilityDescription: "ConvertIt"
        )
    }

    func refreshContent() {
        guard let settings, popover?.isShown == true else { return }
        hostingController?.rootView = AnyView(PopoverView(settings: settings, onClose: { [weak self] in
            self?.closePopover()
        }))
    }

    @objc private func handleOpenPopover() {
        NSApp.activate(ignoringOtherApps: true)
        showPopover()
    }

    @objc private func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let settings, let button = statusItem?.button else { return }

        if popover == nil {
            let popover = NSPopover()
            popover.behavior = .applicationDefined
            popover.animates = true
            popover.delegate = self
            self.popover = popover
        }

        hostingController = NSHostingController(
            rootView: AnyView(PopoverView(settings: settings, onClose: { [weak self] in
                self?.closePopover()
            }))
        )
        popover?.contentViewController = hostingController
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        settings.requestQuickInputFocus()
        installOutsideClickMonitors()
    }

    func closePopover() {
        removeOutsideClickMonitors()
        popover?.performClose(nil)
    }

    var isPopoverShown: Bool {
        popover?.isShown == true
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        let handler: (NSEvent) -> Void = { [weak self] event in
            Task { @MainActor in
                self?.handleOutsideClick(event)
            }
        }

        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: handler) {
            outsideClickMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in
            handler(event)
            return event
        }) {
            outsideClickMonitors.append(local)
        }
    }

    private func removeOutsideClickMonitors() {
        for monitor in outsideClickMonitors {
            NSEvent.removeMonitor(monitor)
        }
        outsideClickMonitors.removeAll()
    }

    private func handleOutsideClick(_ event: NSEvent) {
        guard popover?.isShown == true else { return }
        if NSApp.modalWindow != nil { return }

        let screenPoint = NSEvent.mouseLocation

        if let button = statusItem?.button, let window = button.window {
            let buttonFrame = button.convert(button.bounds, to: nil)
            let screenButtonFrame = window.convertToScreen(buttonFrame)
            if screenButtonFrame.contains(screenPoint) {
                return
            }
        }

        for window in NSApp.windows where window.isVisible {
            if window.frame.contains(screenPoint) {
                return
            }
        }

        closePopover()
    }
}

extension StatusItemController: NSPopoverDelegate {
    nonisolated func popoverWillClose(_ notification: Notification) {
        Task { @MainActor in
            removeOutsideClickMonitors()
        }
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            hostingController = nil
        }
    }
}
