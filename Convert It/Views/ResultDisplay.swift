import SwiftUI

struct CopyResultButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .help(copied ? "Copied" : "Copy result")
        .disabled(text.isEmpty)
    }
}

struct ResultDisplay: View {
    let result: ConversionResult
    var onPin: (() -> Void)?
    var onUseResult: (() -> Void)?

    private var valueParts: (number: String, unit: String?) {
        let value = result.value.trimmingCharacters(in: .whitespaces)
        guard let lastSpace = value.lastIndex(of: " ") else {
            return (value, nil)
        }

        let numberPart = String(value[..<lastSpace])
        let unitPart = String(value[value.index(after: lastSpace)...])
        let numberHasDigit = numberPart.contains(where: \.isNumber)
        let unitLooksValid = !unitPart.isEmpty && unitPart.count <= 12 && numberHasDigit

        if unitLooksValid {
            return (numberPart, unitPart)
        }
        return (value, nil)
    }

    var body: some View {
        if result == .empty {
            EmptyView()
        } else {
            resultCard
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                if let onUseResult {
                    resultActionButton(systemName: "arrow.turn.down.right", help: "Use result as input", action: onUseResult)
                }
                if let onPin {
                    resultActionButton(systemName: "pin", help: "Pin this conversion", action: onPin)
                }
                CopyResultButton(text: result.copyText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(valueParts.number)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                if let unit = valueParts.unit {
                    Text(unit)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let detail = result.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func resultActionButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
