import SwiftUI

struct TimeZonePickerView: View {
    let title: String
    @Binding var selection: String
    @State private var searchText = ""

    private var options: [String] {
        let matches = searchText.isEmpty
            ? TimeZoneCatalog.common
            : TimeZoneCatalog.filtered(searchText)
        if matches.contains(selection) {
            return matches
        }
        return [selection] + matches.filter { $0 != selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search \(title.lowercased()) timezone", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Picker(title, selection: $selection) {
                ForEach(options.prefix(60), id: \.self) { id in
                    Text(TimeZoneCatalog.label(for: id)).tag(id)
                }
            }
            .labelsHidden()
        }
    }
}
