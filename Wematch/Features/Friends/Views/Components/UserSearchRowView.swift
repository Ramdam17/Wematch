import SwiftUI

struct UserSearchRowView: View {
    let profile: UserProfile
    let status: UserFriendStatus
    var onAdd: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(hex: "C084FC").gradient)

            Text(profile.username)
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textPrimary)

            Spacer()

            switch status {
            case .canAdd:
                Button {
                    onAdd()
                } label: {
                    Text("Add")
                        .font(WematchTypography.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "C084FC"))
                        .clipShape(Capsule())
                }
            case .pending:
                StatusBadge(text: "Pending", style: .pending)
            case .alreadyFriends:
                StatusBadge(text: "Friends", style: .friends)
            }
        }
        .padding(.vertical, 4)
    }
}
