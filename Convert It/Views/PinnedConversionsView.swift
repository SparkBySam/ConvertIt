import SwiftUI

struct PinnedConversionsView: View {
    let items: [PinnedConversion]
    var onSelect: (PinnedConversion) -> Void
    var onUnpin: (PinnedConversion) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pinned")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(items) { item in
                        HStack(spacing: 4) {
                            Button {
                                onSelect(item)
                            } label: {
                                Text(item.label)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onUnpin(item)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
