import SwiftUI

struct FriendRowView: View {
    let profile: UserProfile

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "67E8F9").gradient)

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

                StatusBadge(text: "Friends", style: .friends)
            }
        }
    }
}
