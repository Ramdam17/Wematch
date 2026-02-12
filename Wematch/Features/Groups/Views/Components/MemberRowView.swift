import SwiftUI

struct MemberRowView: View {
    let profile: UserProfile
    let isGroupAdmin: Bool
    let canRemove: Bool
    var onRemove: (() -> Void)?

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(hex: "C084FC").gradient)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.username)
                    .font(WematchTypography.body)
                    .foregroundStyle(WematchTheme.textPrimary)

                if let displayName = profile.displayName {
                    Text(displayName)
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
                }
            }

            Spacer()

            if isGroupAdmin {
                StatusBadge(text: "Admin", style: .admin)
            }

            if canRemove {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
