import SwiftUI

/// Semantic status tints, mirroring the Figma `StatusBadge` variants
/// (`Status = Pending | Info | Accent | Success | Danger`).
///
/// The style names describe meaning, not appearance, so a badge cannot be given an
/// arbitrary colour with an unchecked contrast ratio — which is how G2 happened.
enum BadgeStyle {
    case pending
    case info
    case accent
    case success
    case danger

    var tint: TintPair {
        switch self {
        case .pending: WematchTheme.tintPending
        case .info: WematchTheme.tintInfo
        case .accent: WematchTheme.tintAccent
        case .success: WematchTheme.tintSuccess
        case .danger: WematchTheme.tintDanger
        }
    }
}

struct StatusBadge: View {
    let text: String
    let style: BadgeStyle

    var body: some View {
        Text(text)
            .font(WematchTypography.captionEmphasized)
            .foregroundStyle(style.tint.on)
            .padding(.horizontal, 10)
            .padding(.vertical, WematchTheme.paddingXSmall)
            .background(style.tint.fill)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            StatusBadge(text: "Pending", style: .pending)
            StatusBadge(text: "Friends", style: .info)
            StatusBadge(text: "Admin", style: .accent)
        }
        HStack(spacing: 12) {
            StatusBadge(text: "Live", style: .success)
            StatusBadge(text: "Failed", style: .danger)
        }
    }
    .padding()
    .background(WematchTheme.backgroundGradient)
}
