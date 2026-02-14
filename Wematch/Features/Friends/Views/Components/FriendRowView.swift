import SwiftUI

struct FriendRowView: View {
    let profile: UserProfile
    var onStartRoom: (() -> Void)? = nil

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

                if let onStartRoom {
                    Button {
                        onStartRoom()
                    } label: {
                        Image(systemName: "heart.circle.fill")
                            .font(.title2)
                            .foregroundStyle(WematchTheme.primaryGradient)
                    }
                    .buttonStyle(.plain)
                }

                StatusBadge(text: "Friends", style: .friends)
            }
        }
    }
}
