import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 48

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(iconColor.gradient)
                .accessibilityHidden(true)

            Text(title)
                .font(WematchTypography.title2)
                .foregroundStyle(WematchTheme.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(WematchTypography.body)
                    .foregroundStyle(WematchTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
