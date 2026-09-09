import SwiftUI

struct ManualTimeField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                TextField(label, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 44)
                    .multilineTextAlignment(.center)
                    .font(.body.monospacedDigit())
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }

                Picker(label, selection: $value) {
                    ForEach(Array(range), id: \.self) { number in
                        Text(String(format: "%02d", number))
                            .tag(number)
                    }
                }
                .labelsHidden()
                .frame(width: 58)
            }
        }
        .onAppear {
            text = formatted(value)
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            text = formatted(newValue)
        }
    }

    private func commit() {
        guard let parsed = Int(text) else {
            text = formatted(value)
            return
        }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        value = clamped
        text = formatted(clamped)
    }

    private func formatted(_ number: Int) -> String {
        String(format: "%02d", number)
    }
}
