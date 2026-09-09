import SwiftUI

struct QuickSyntaxCheatsheet: View {
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                cheatLine("72f to c", "Temperature")
                cheatLine("c from 72f", "Reverse syntax")
                cheatLine("100 mi to km", "Distance / weight / volume")
                cheatLine("25 mpg to l/100km", "Fuel economy")
                cheatLine("100 usd to eur", "Currency")
                cheatLine("18% of 85", "Percentage")
                cheatLine("20% tip on 50 split 4", "Tip calculator")
                cheatLine("3pm pst to est", "Time zones")
                cheatLine("14:30 utc to tokyo", "24-hour time zones")
            }
            .padding(.top, 4)
        } label: {
            Label("Syntax help", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func cheatLine(_ example: String, _ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(example)
                .font(.caption2.monospaced())
            Text(note)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
