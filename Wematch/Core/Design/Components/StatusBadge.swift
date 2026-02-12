import SwiftUI

enum BadgeStyle {
    case pending
    case friends
    case admin
    case member
    case custom(Color)

    var color: Color {
        switch self {
        case .pending: Color.orange
        case .friends: Color(hex: "67E8F9")
        case .admin: Color(hex: "C084FC")
        case .member: Color(hex: "34D399")
        case .custom(let color): color
        }
    }
}

struct StatusBadge: View {
    let text: String
    let style: BadgeStyle

    var body: some View {
        Text(text)
            .font(WematchTypography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(style.color)
            .clipShape(Capsule())
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusBadge(text: "Pending", style: .pending)
        StatusBadge(text: "Friends", style: .friends)
        StatusBadge(text: "Admin", style: .admin)
        StatusBadge(text: "Member", style: .member)
    }
}
