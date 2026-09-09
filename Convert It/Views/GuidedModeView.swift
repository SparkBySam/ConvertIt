import SwiftUI

struct GuidedModeView: View {
    @Bindable var settings: AppSettings

    @State private var category: ConversionCategory = .temperature
    @State private var valueText = "1"
    @State private var fromUnit: ConversionUnit = .fahrenheit
    @State private var toUnit: ConversionUnit = .celsius
    @State private var manualHour = 12
    @State private var manualMinute = 0
    @State private var selectedDate = Date()
    @State private var fromTimeZoneID = TimeZone.current.identifier
    @State private var toTimeZoneID = "America/New_York"
    @State private var now = Date()
    @State private var currencyResult: ConversionResult?

    @State private var percentageMode: PercentageMode = .percentOf
    @State private var percentageA = "18"
    @State private var percentageB = "85"

    @State private var billAmount = "50"
    @State private var tipPercent = "20"
    @State private var splitCount = 1

    private var numericValue: Double? {
        Double(valueText.replacingOccurrences(of: ",", with: ""))
    }

    private var activeTime: (hour: Int, minute: Int) {
        if settings.timeUseManualTime {
            return (manualHour, manualMinute)
        }
        return currentTime(in: fromTimeZoneID)
    }

    private var activeDate: Date {
        settings.timeUseManualTime ? selectedDate : now
    }

    private var result: ConversionResult {
        if category == .currency, let currencyResult { return currencyResult }
        return syncResult
    }

    private var syncResult: ConversionResult {
        switch category {
        case .timeZone:
            let time = activeTime
            return ConversionEngine.convertTime(
                date: activeDate,
                hour: time.hour,
                minute: time.minute,
                from: fromTimeZoneID,
                to: toTimeZoneID
            ) ?? .empty
        case .percentage:
            guard let a = Double(percentageA), let b = Double(percentageB) else { return .empty }
            return CalculatorEngine.percentage(
                mode: percentageMode,
                a: a,
                b: b,
                decimalPlaces: settings.resolvedDecimalPlaces
            ) ?? .empty
        case .tip:
            guard let bill = Double(billAmount),
                  let percent = Double(tipPercent) else { return .empty }
            return CalculatorEngine.tip(bill: bill, tipPercent: percent, split: splitCount) ?? .empty
        case .currency:
            return .empty
        default:
            guard let value = numericValue,
                  let converted = ConversionEngine.convert(
                    value: value,
                    from: fromUnit,
                    to: toUnit,
                    dataSizeBinary: settings.dataSizeBinary,
                    decimalPlaces: settings.resolvedDecimalPlaces
                  ) else {
                return .empty
            }
            return converted
        }
    }

    private var recentQuery: String? {
        switch category {
        case .timeZone:
            let time = activeTime
            return String(format: "%02d:%02d %@ → %@", time.hour, time.minute, fromTimeZoneID, toTimeZoneID)
        case .percentage:
            return "\(percentageMode.label): \(percentageA), \(percentageB)"
        case .tip:
            return "Tip \(tipPercent)% on \(billAmount)" + (splitCount > 1 ? " · split \(splitCount)" : "")
        case .currency:
            guard numericValue != nil else { return nil }
            return "\(valueText) \(fromUnit.shortLabel) → \(toUnit.shortLabel)"
        default:
            guard numericValue != nil else { return nil }
            return "\(valueText) \(fromUnit.shortLabel) → \(toUnit.shortLabel)"
        }
    }

    private var shouldRunClock: Bool {
        category == .timeZone && !settings.timeUseManualTime
    }

    private var categoryBinding: Binding<ConversionCategory> {
        Binding(
            get: { category },
            set: { newCategory in
                category = newCategory
                currencyResult = nil
                resetUnits(for: newCategory)
            }
        )
    }

    var body: some View {
        mainContent
            .onAppear {
                if settings.pendingRestoreKind == nil {
                    category = settings.defaultGuidedCategory
                    resetUnits(for: category)
                }
                validateUnitSelections()
                refreshCurrencyIfNeeded()
                applyPendingRestoreIfNeeded()
            }
            .onChange(of: recordToken) { _, _ in
                refreshCurrencyIfNeeded()
                recordRecentIfNeeded()
            }
            .onChange(of: settings.dataSizeBinary) { _, _ in
                validateUnitSelections()
            }
            .task(id: shouldRunClock) {
                guard shouldRunClock else { return }
                now = Date()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    now = Date()
                    recordRecentIfNeeded()
                }
            }
            .onChange(of: settings.timeUseManualTime) { _, useManual in
                guard useManual else { return }
                seedManualTimeFromClock()
            }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            PinnedConversionsView(
                items: settings.pinnedConversions.items,
                onSelect: { applyPinned($0) },
                onUnpin: { settings.pinnedConversions.unpin($0) }
            )

            VStack(alignment: .leading, spacing: 16) {
                Picker("Category", selection: categoryBinding) {
                    ForEach(ConversionCategory.allCases) { cat in
                        Text(cat.label).tag(cat)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                categoryInputs
            }

            ResultDisplay(
                result: result,
                onPin: canPin ? { pinCurrent() } : nil,
                onUseResult: result == .empty || category.isCalculator ? nil : { useResultAsInput() }
            )
            .padding(.top, 2)

            RecentConversionsView(
                items: settings.recentConversions.items,
                isExpanded: $settings.recentListExpanded,
                onSelect: { applyRecent($0) },
                onClear: { settings.recentConversions.clear() }
            )
        }
    }

    private var recordToken: String {
        [
            category.rawValue,
            valueText,
            fromUnit.id,
            toUnit.id,
            percentageMode.rawValue,
            percentageA,
            percentageB,
            billAmount,
            tipPercent,
            String(splitCount),
            fromTimeZoneID,
            toTimeZoneID,
            String(manualHour),
            String(manualMinute),
            ISO8601DateFormatter().string(from: selectedDate),
            settings.timeUseManualTime ? "1" : "0",
        ].joined(separator: "|")
    }

    private var canPin: Bool {
        result != .empty && restoreKind != nil && restoreData != nil && recentQuery != nil
    }

    @ViewBuilder
    private var categoryInputs: some View {
        switch category {
        case .timeZone:
            timeZoneInputs
        case .percentage:
            percentageInputs
        case .tip:
            tipInputs
        case .currency:
            currencyInputs
        default:
            standardInputs
        }
    }

    @ViewBuilder
    private var standardInputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Value", text: $valueText)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                unitPicker("From", selection: $fromUnit)
                    .frame(maxWidth: .infinity)
                Button(action: swapUnits) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24)
                .help("Swap units")
                unitPicker("To", selection: $toUnit)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var currencyInputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Amount", text: $valueText)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                unitPicker("From", selection: $fromUnit)
                    .frame(maxWidth: .infinity)
                Button(action: swapUnits) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24)
                unitPicker("To", selection: $toUnit)
                    .frame(maxWidth: .infinity)
            }

            HStack {
                if settings.currencyRates.isLoading {
                    ProgressView().controlSize(.small)
                    Text("Updating rates…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let error = settings.currencyRates.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button("Refresh rates") {
                    Task { await settings.currencyRates.refresh() }
                }
                .buttonStyle(.borderless)
                .font(.caption2)
            }
        }
    }

    @ViewBuilder
    private var percentageInputs: some View {
        Picker("Mode", selection: $percentageMode) {
            ForEach(PercentageMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)

        HStack(spacing: 8) {
            TextField(percentageMode.fieldALabel, text: $percentageA)
                .textFieldStyle(.roundedBorder)
            TextField(percentageMode.fieldBLabel, text: $percentageB)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var tipInputs: some View {
        TextField("Bill amount", text: $billAmount)
            .textFieldStyle(.roundedBorder)

        HStack(spacing: 8) {
            TextField("Tip %", text: $tipPercent)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)

            ForEach([15, 18, 20, 25], id: \.self) { preset in
                Button("\(preset)%") {
                    tipPercent = String(preset)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }

        Stepper("Split \(splitCount) way\(splitCount == 1 ? "" : "s")", value: $splitCount, in: 1...20)
            .font(.caption)
    }

    @ViewBuilder
    private var timeZoneInputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Manual time", isOn: $settings.timeUseManualTime)
                .toggleStyle(.checkbox)

            if settings.timeUseManualTime {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)

                HStack(spacing: 10) {
                    ManualTimeField(label: "Hour", value: $manualHour, range: 0...23)
                    Text(":")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                    ManualTimeField(label: "Min", value: $manualMinute, range: 0...59)
                }
            } else {
                currentTimeDisplay
            }

            HStack(spacing: 10) {
                TimeZonePickerView(title: "From", selection: $fromTimeZoneID)
                    .frame(maxWidth: .infinity)
                Button(action: swapTimeZones) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24)
                TimeZonePickerView(title: "To", selection: $toTimeZoneID)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var currentTimeDisplay: some View {
        let time = currentTime(in: fromTimeZoneID)
        HStack {
            Text("Current time")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%02d:%02d", time.hour, time.minute))
                .font(.body.monospacedDigit())
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private func applyPendingRestoreIfNeeded() {
        guard let kind = settings.pendingRestoreKind,
              let data = settings.pendingRestoreData else { return }
        settings.pendingRestoreKind = nil
        settings.pendingRestoreData = nil
        applyRestore(kind: kind, data: data)
    }

    private func pinCurrent() {
        guard let kind = restoreKind, let data = restoreData, let query = recentQuery else { return }
        settings.pinnedConversions.pin(label: query, restoreKind: kind, restoreData: data)
    }

    private func useResultAsInput() {
        let value = result.numericValue
        guard value != "—" else { return }
        valueText = value
    }

    private func refreshCurrencyIfNeeded() {
        guard category == .currency,
              let value = numericValue,
              let from = fromUnit.currencyCode,
              let to = toUnit.currencyCode else {
            currencyResult = nil
            return
        }
        Task {
            await settings.currencyRates.refreshIfNeeded()
            await MainActor.run {
                currencyResult = settings.currencyRates.convert(
                    value: value,
                    from: from,
                    to: to,
                    decimalPlaces: settings.resolvedDecimalPlaces
                ) ?? .empty
                recordRecentIfNeeded()
            }
        }
    }

    private func recordRecentIfNeeded() {
        guard result != .empty, let query = recentQuery else { return }
        settings.recentConversions.record(
            query: query,
            result: result.value,
            restoreKind: restoreKind,
            restoreData: restoreData
        )
    }

    private var restoreKind: RecentConversion.RestoreKind? {
        switch category {
        case .timeZone: .timeZone
        case .percentage: .percentage
        case .tip: .tip
        case .currency: .currency
        default: .unit
        }
    }

    private var restoreData: [String: String]? {
        switch category {
        case .timeZone:
            let time = activeTime
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return [
                "fromTZ": fromTimeZoneID,
                "toTZ": toTimeZoneID,
                "hour": String(time.hour),
                "minute": String(time.minute),
                "manual": settings.timeUseManualTime ? "1" : "0",
                "date": formatter.string(from: activeDate),
            ]
        case .percentage:
            return [
                "mode": percentageMode.rawValue,
                "a": percentageA,
                "b": percentageB,
            ]
        case .tip:
            return [
                "bill": billAmount,
                "percent": tipPercent,
                "split": String(splitCount),
            ]
        case .currency:
            return [
                "value": valueText,
                "from": fromUnit.id,
                "to": toUnit.id,
            ]
        default:
            return [
                "category": category.rawValue,
                "value": valueText,
                "from": fromUnit.id,
                "to": toUnit.id,
            ]
        }
    }

    private func applyRecent(_ item: RecentConversion) {
        if item.restoreKind == .quick {
            settings.unitMode = .quick
            if let input = item.restoreData?["input"] {
                settings.pendingQuickInput = input
            }
            return
        }
        applyRestore(kind: item.restoreKind, data: item.restoreData)
    }

    private func applyPinned(_ item: PinnedConversion) {
        if item.restoreKind == .quick {
            settings.unitMode = .quick
            settings.pendingQuickInput = item.restoreData["input"]
            return
        }
        applyRestore(kind: item.restoreKind, data: item.restoreData)
    }

    private func applyRestore(kind: RecentConversion.RestoreKind?, data: [String: String]?) {
        guard let kind, let data else { return }

        switch kind {
        case .quick:
            settings.unitMode = .quick
        case .unit:
            if let cat = data["category"], let parsedCategory = ConversionCategory(rawValue: cat) {
                category = parsedCategory
            }
            if let value = data["value"] { valueText = value }
            applyUnitSelections(from: data)
            validateUnitSelections()
        case .percentage:
            category = .percentage
            if let mode = data["mode"], let parsed = PercentageMode(rawValue: mode) {
                percentageMode = parsed
            }
            if let a = data["a"] { percentageA = a }
            if let b = data["b"] { percentageB = b }
        case .tip:
            category = .tip
            if let bill = data["bill"] { billAmount = bill }
            if let percent = data["percent"] { tipPercent = percent }
            if let split = data["split"], let count = Int(split) { splitCount = count }
        case .timeZone:
            category = .timeZone
            if let from = data["fromTZ"] ?? data["from"] { fromTimeZoneID = from }
            if let to = data["toTZ"] ?? data["to"] { toTimeZoneID = to }
            if data["manual"] == "1" {
                settings.timeUseManualTime = true
                if let hour = data["hour"], let h = Int(hour) { manualHour = h }
                if let minute = data["minute"], let m = Int(minute) { manualMinute = m }
                if let dateString = data["date"],
                   let date = ISO8601DateFormatter().date(from: dateString) {
                    selectedDate = date
                }
            } else {
                settings.timeUseManualTime = false
            }
        case .currency:
            category = .currency
            if let value = data["value"] { valueText = value }
            applyUnitSelections(from: data)
            validateUnitSelections()
            refreshCurrencyIfNeeded()
        }
    }

    private func applyUnitSelections(from data: [String: String]) {
        let units = category.units(dataSizeBinary: settings.dataSizeBinary)
        if let from = data["from"], let unit = units.first(where: { $0.id == from }) {
            fromUnit = unit
        }
        if let to = data["to"], let unit = units.first(where: { $0.id == to }) {
            toUnit = unit
        }
    }

    private func swapUnits() {
        let temp = fromUnit
        fromUnit = toUnit
        toUnit = temp
    }

    private func swapTimeZones() {
        let temp = fromTimeZoneID
        fromTimeZoneID = toTimeZoneID
        toTimeZoneID = temp
    }

    private func currentTime(in timeZoneID: String) -> (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return (
            calendar.component(.hour, from: now),
            calendar.component(.minute, from: now)
        )
    }

    private func seedManualTimeFromClock() {
        let current = currentTime(in: fromTimeZoneID)
        manualHour = current.hour
        manualMinute = current.minute
        selectedDate = Date()
    }

    private func unitPicker(_ title: String, selection: Binding<ConversionUnit>) -> some View {
        let units = category.units(dataSizeBinary: settings.dataSizeBinary)
        return Picker(title, selection: selection) {
            ForEach(units) { unit in
                Text(unit.label).tag(unit)
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private func validateUnitSelections() {
        let units = category.units(dataSizeBinary: settings.dataSizeBinary)
        guard !units.isEmpty else { return }
        if !units.contains(fromUnit) {
            fromUnit = units[0]
        }
        if !units.contains(toUnit) {
            toUnit = units.count > 1 ? units[1] : units[0]
        }
    }

    private func resetUnits(for category: ConversionCategory) {
        switch category {
        case .temperature:
            fromUnit = .fahrenheit
            toUnit = .celsius
        case .distance:
            fromUnit = .miles
            toUnit = .kilometers
        case .weight:
            fromUnit = .pounds
            toUnit = .kilograms
        case .volume:
            fromUnit = .cups
            toUnit = .milliliters
        case .dataSize:
            if settings.dataSizeBinary {
                fromUnit = .mebibytes
                toUnit = .gibibytes
            } else {
                fromUnit = .megabytes
                toUnit = .gigabytes
            }
        case .speed:
            fromUnit = .milesPerHour
            toUnit = .kilometersPerHour
        case .area:
            fromUnit = .squareFeet
            toUnit = .squareMeters
        case .pressure:
            fromUnit = .psi
            toUnit = .bar
        case .energy:
            fromUnit = .kilowattHours
            toUnit = .megajoules
        case .fuelEconomy:
            fromUnit = .milesPerGallon
            toUnit = .litersPer100Km
        case .currency:
            fromUnit = .currency(settings.defaultCurrencyFrom)
            toUnit = .currency(settings.defaultCurrencyTo)
        case .timeZone:
            fromTimeZoneID = TimeZone.current.identifier
            toTimeZoneID = "America/New_York"
            now = Date()
            seedManualTimeFromClock()
        case .percentage, .tip:
            break
        }
    }
}

#Preview {
    GuidedModeView(settings: AppSettings())
        .padding()
        .frame(width: 320)
}
