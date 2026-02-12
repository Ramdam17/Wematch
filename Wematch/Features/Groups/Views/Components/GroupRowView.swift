import SwiftUI

struct GroupRowView: View {
    let group: Group
    let isAdmin: Bool

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(WematchTypography.headline)
                        .foregroundStyle(WematchTheme.textPrimary)

                    HStack(spacing: 12) {
                        Label("\(group.memberIDs.count + 1)/20", systemImage: "person.2.fill")
                            .font(WematchTypography.caption)
                            .foregroundStyle(WematchTheme.textSecondary)

                        Label(group.code, systemImage: "number")
                            .font(WematchTypography.caption)
                            .foregroundStyle(WematchTheme.textSecondary)
                    }
                }

                Spacer()

                StatusBadge(
                    text: isAdmin ? "Admin" : "Member",
                    style: isAdmin ? .admin : .member
                )
            }
        }
    }
}
