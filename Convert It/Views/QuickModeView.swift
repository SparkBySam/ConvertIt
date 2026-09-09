import SwiftUI

struct QuickModeView: View {
    @Bindable var settings: AppSettings
    @State private var input = ""
    @State private var currencyResult: ConversionResult?
    @State private var copiedFlash = false

    private var parsedResult: QuickParseResult? {
        QuickInputParser.parse(input)
    }

    private var result: ConversionResult {
        if let currencyResult { return currencyResult }
        return syncResult
    }

    private var isParsing: Bool {
        parsedResult != nil
    }

    private var decimalPlaces: Int? {
        settings.resolvedDecimalPlaces
    }

    private var syncResult: ConversionResult {
        switch parsedResult {
        case .conversion(let parsed):
            guard let converted = ConversionEngine.convert(
                value: parsed.value,
                from: parsed.fromUnit,
                to: parsed.toUnit,
                dataSizeBinary: settings.dataSizeBinary,
                decimalPlaces: decimalPlaces
            ) else {
                return .empty
            }
            return converted
        case .percentage(let mode, let a, let b):
            return CalculatorEngine.percentage(mode: mode, a: a, b: b, decimalPlaces: decimalPlaces) ?? .empty
        case .tip(let bill, let percent, let split):
            return CalculatorEngine.tip(bill: bill, tipPercent: percent, split: split) ?? .empty
        case .timeZone(let hour, let minute, let fromID, let toID):
            return ConversionEngine.convertTime(
                date: Date(),
                hour: hour,
                minute: minute,
                from: fromID,
                to: toID
            ) ?? .empty
        case .currency:
            return .empty
        case nil:
            return .empty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PinnedConversionsView(
                items: settings.pinnedConversions.items,
                onSelect: { applyPinned($0) },
                onUnpin: { settings.pinnedConversions.unpin($0) }
            )

            FocusableTextField(
                text: $input,
                placeholder: "e.g. 72f to c, 3pm pst to est, 1,000 usd to eur",
                focusToken: settings.focusQuickInputToken,
                onReturn: copyResultIfPossible
            )

            QuickSyntaxCheatsheet()

            RecentConversionsView(
                items: settings.recentConversions.items,
                isExpanded: $settings.recentListExpanded,
                filterText: isParsing ? "" : input,
                onSelect: { applyRecent($0) },
                onClear: { settings.recentConversions.clear() }
            )

            if input.isEmpty {
                Text("72f to c · 3pm pst to est · 18% of 85")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if result == .empty && !isParsing {
                Text("Couldn't parse that. Open syntax help for examples.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ResultDisplay(
                result: result,
                onPin: canPin ? { pinCurrent() } : nil,
                onUseResult: result == .empty ? nil : { useResultAsInput() }
            )
            .padding(.top, 4)

            if copiedFlash {
                Text("Copied to clipboard")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let pending = settings.pendingQuickInput {
                input = pending
                settings.pendingQuickInput = nil
            }
            refreshCurrencyIfNeeded()
        }
        .onChange(of: input) { _, _ in
            currencyResult = nil
            refreshCurrencyIfNeeded()
            recordRecentIfNeeded()
        }
        .onChange(of: result) { _, newResult in
            guard settings.autoCopyResult, newResult != .empty else { return }
            copyToPasteboard(newResult.copyText)
        }
    }

    private var canPin: Bool {
        result != .empty && restorePayload != nil
    }

    private var restorePayload: (RecentConversion.RestoreKind, [String: String])? {
        switch parsedResult {
        case .conversion(let parsed):
            return (.unit, [
                "category": parsed.fromUnit.category?.rawValue ?? "",
                "value": String(parsed.value),
                "from": parsed.fromUnit.id,
                "to": parsed.toUnit.id,
            ])
        case .percentage(let mode, let a, let b):
            return (.percentage, ["mode": mode.rawValue, "a": String(a), "b": String(b)])
        case .tip(let bill, let percent, let split):
            return (.tip, ["bill": String(bill), "percent": String(percent), "split": String(split)])
        case .currency(let value, let from, let to):
            return (.currency, ["value": String(value), "from": from, "to": to])
        case .timeZone(let hour, let minute, let fromID, let toID):
            return (.timeZone, [
                "hour": String(hour),
                "minute": String(minute),
                "from": fromID,
                "to": toID,
            ])
        case nil:
            return nil
        }
    }

    private func copyResultIfPossible() {
        guard settings.copyResultOnReturn else { return }
        guard result != .empty else { return }
        copyToPasteboard(result.copyText)
        copiedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copiedFlash = false
        }
    }

    private func useResultAsInput() {
        let value = result.numericValue
        guard value != "—" else { return }
        input = value
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func pinCurrent() {
        guard let (kind, data) = restorePayload else { return }
        settings.pinnedConversions.pin(label: input, restoreKind: kind, restoreData: data)
    }

    private func refreshCurrencyIfNeeded() {
        guard case .currency(let value, let from, let to) = parsedResult else { return }
        Task {
            await settings.currencyRates.refreshIfNeeded()
            await MainActor.run {
                currencyResult = settings.currencyRates.convert(
                    value: value,
                    from: from,
                    to: to,
                    decimalPlaces: decimalPlaces
                ) ?? .empty
                recordRecentIfNeeded()
            }
        }
    }

    private func recordRecentIfNeeded() {
        guard result != .empty else { return }
        settings.recentConversions.record(
            query: input,
            result: result.value,
            restoreKind: .quick,
            restoreData: ["input": input]
        )
    }

    private func applyRecent(_ item: RecentConversion) {
        if item.restoreKind == .quick, let input = item.restoreData?["input"] {
            self.input = input
            return
        }
        applyRestore(kind: item.restoreKind, data: item.restoreData)
    }

    private func applyPinned(_ item: PinnedConversion) {
        if item.restoreKind == .quick, let input = item.restoreData["input"] {
            self.input = input
            return
        }
        applyRestore(kind: item.restoreKind, data: item.restoreData)
    }

    private func applyRestore(kind: RecentConversion.RestoreKind?, data: [String: String]?) {
        guard let kind else { return }
        if kind == .quick, let input = data?["input"] {
            self.input = input
            return
        }
        settings.unitMode = .guided
        settings.pendingRestoreKind = kind
        settings.pendingRestoreData = data
    }
}

#Preview {
    QuickModeView(settings: AppSettings())
        .padding()
        .frame(width: 320)
}
