import AppKit

extension Notification.Name {
    static let convertItOpenPopover = Notification.Name("convertItOpenPopover")
    static let convertItImportFiles = Notification.Name("convertItImportFiles")
    static let convertItQuickInput = Notification.Name("convertItQuickInput")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        FFmpegProvisioner.prepareBundledCopyIfNeeded()
        FFmpegProvisioner.warmUp()
        StatusItemController.shared.install(settings: AppController.settings)
    }

    @objc func convertText(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: NSErrorPointer
    ) -> NSAttributedString? {
        guard let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }

        if let result = evaluateQuickInput(text) {
            return NSAttributedString(string: result)
        }

        DispatchQueue.main.async {
            AppController.settings.pendingQuickInput = text
            AppController.settings.selectedTab = .convert
            AppController.settings.unitMode = .quick
            StatusItemController.shared.showPopover()
        }
        return NSAttributedString(string: text)
    }

    @objc func convertMediaFiles(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: NSErrorPointer
    ) -> NSAttributedString? {
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
        ]) as? [URL], !items.isEmpty else {
            return nil
        }

        DispatchQueue.main.async {
            AppController.settings.pendingImportURLs = items
            AppController.settings.selectedTab = .media
            AppController.settings.mediaTask = .convert
            StatusItemController.shared.showPopover()
        }
        return nil
    }

    private func evaluateQuickInput(_ text: String) -> String? {
        let settings = AppController.settings
        let decimalPlaces = settings.resolvedDecimalPlaces

        switch QuickInputParser.parse(text) {
        case .conversion(let parsed):
            return ConversionEngine.convert(
                value: parsed.value,
                from: parsed.fromUnit,
                to: parsed.toUnit,
                dataSizeBinary: settings.dataSizeBinary,
                decimalPlaces: decimalPlaces
            )?.value
        case .percentage(let mode, let a, let b):
            return CalculatorEngine.percentage(mode: mode, a: a, b: b, decimalPlaces: decimalPlaces)?.value
        case .tip(let bill, let percent, let split):
            return CalculatorEngine.tip(bill: bill, tipPercent: percent, split: split)?.value
        case .currency(let value, let from, let to):
            return settings.currencyRates.convert(
                value: value,
                from: from,
                to: to,
                decimalPlaces: decimalPlaces
            )?.value
        case .timeZone(let hour, let minute, let fromID, let toID):
            return ConversionEngine.convertTime(
                date: Date(),
                hour: hour,
                minute: minute,
                from: fromID,
                to: toID
            )?.value
        case nil:
            return nil
        }
    }
}
