import SwiftUI

struct RecentConversionsView: View {
    let items: [RecentConversion]
    @Binding var isExpanded: Bool
    var filterText: String = ""
    var onSelect: ((RecentConversion) -> Void)?
    var onClear: (() -> Void)?

    private var filteredItems: [RecentConversion] {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let query = trimmed.lowercased()
        return items.filter {
            $0.query.lowercased().contains(query) || $0.result.lowercased().contains(query)
        }
    }

    private var isFiltering: Bool {
        !filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button {
                        if !isFiltering {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if !isFiltering {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                            }
                            Text(isFiltering ? "Matching recent" : "Recent")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let onClear, !isFiltering {
                        Button("Clear") {
                            onClear()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption2)
                    }
                }

                if isExpanded || isFiltering {
                    if filteredItems.isEmpty && isFiltering {
                        Text("No matching recent items")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(filteredItems.prefix(RecentConversionStore.limit)) { item in
                                if let onSelect {
                                    Button {
                                        onSelect(item)
                                    } label: {
                                        recentRow(item)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    recentRow(item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func recentRow(_ item: RecentConversion) -> some View {
        HStack(spacing: 8) {
            Text(item.query)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
            Spacer(minLength: 4)
            Text(item.result)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
