import SwiftUI

enum UIStyles {
    static let settingsSectionSpacing: CGFloat = 22
    static let mediaDefaultRowSpacing: CGFloat = 16
    static let popoverMaxContentHeight: CGFloat = 360
}

struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.top, 4)
    }
}

extension View {
    /// Neutral segmented selection — light pill, no accent blue.
    func subtleSegmentedPicker() -> some View {
        tint(Color(nsColor: .selectedContentBackgroundColor))
    }

    /// Keeps view in hierarchy for state but removes it from layout when inactive.
    func tabStackVisible(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .frame(height: isVisible ? nil : 0)
            .clipped()
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
    }
}
