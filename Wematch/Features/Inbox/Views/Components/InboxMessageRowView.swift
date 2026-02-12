import SwiftUI

struct InboxMessageRowView: View {
    let message: InboxMessage
    var onAction: ((InboxAction) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor.gradient)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WematchTypography.body)
                    .fontWeight(message.isRead ? .regular : .semibold)
                    .foregroundStyle(WematchTheme.textPrimary)

                Text(subtitle)
                    .font(WematchTypography.caption)
                    .foregroundStyle(WematchTheme.textSecondary)

                Text(message.createdAt.formatted(.relative(presentation: .named)))
                    .font(WematchTypography.caption)
                    .foregroundStyle(WematchTheme.textSecondary.opacity(0.7))
            }

            Spacer()

            // Action buttons (for actionable messages)
            if hasActions {
                actionButtons
            }
        }
        .padding(.vertical, 4)
        .opacity(message.isRead ? 0.75 : 1.0)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if message.type == .temporaryRoomInvitation {
                Button {
                    onAction?(.join)
                } label: {
                    Text("Join")
                        .font(WematchTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "EC4899"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onAction?(.accept)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                Button {
                    onAction?(.decline)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Display Properties

    private var hasActions: Bool {
        switch message.type {
        case .groupJoinRequest, .friendRequest, .temporaryRoomInvitation:
            true
        default:
            false
        }
    }

    private var iconName: String {
        switch message.type {
        case .groupJoinRequest: "person.badge.plus"
        case .groupRequestAccepted: "checkmark.circle"
        case .groupRequestDeclined: "xmark.circle"
        case .groupDeleted: "trash"
        case .friendRequest: "person.badge.plus"
        case .friendRequestAccepted: "person.2.fill"
        case .friendRequestDeclined: "person.slash"
        case .temporaryRoomInvitation: "heart.circle"
        }
    }

    private var iconColor: Color {
        switch message.type {
        case .groupJoinRequest: .orange
        case .groupRequestAccepted: .green
        case .groupRequestDeclined: .red
        case .groupDeleted: .red
        case .friendRequest: Color(hex: "67E8F9")
        case .friendRequestAccepted: .green
        case .friendRequestDeclined: .red
        case .temporaryRoomInvitation: Color(hex: "EC4899")
        }
    }

    private var title: String {
        let username = message.payload["username"] ?? message.payload["senderUsername"] ?? "Someone"
        let groupName = message.payload["groupName"] ?? "a group"

        switch message.type {
        case .groupJoinRequest:
            return "\(username) wants to join \(groupName)"
        case .groupRequestAccepted:
            return "Joined \(groupName)"
        case .groupRequestDeclined:
            return "Request declined for \(groupName)"
        case .groupDeleted:
            return "\(groupName) was deleted"
        case .friendRequest:
            return "\(username) sent you a friend request"
        case .friendRequestAccepted:
            return "\(username) accepted your friend request"
        case .friendRequestDeclined:
            return "\(username) declined your friend request"
        case .temporaryRoomInvitation:
            return "\(username) invited you to a room"
        }
    }

    private var subtitle: String {
        switch message.type {
        case .groupJoinRequest:
            "Tap to accept or decline"
        case .groupRequestAccepted:
            "You are now a member"
        case .groupRequestDeclined:
            "Your join request was not approved"
        case .groupDeleted:
            "This group no longer exists"
        case .friendRequest:
            "Tap to accept or decline"
        case .friendRequestAccepted:
            "You are now friends"
        case .friendRequestDeclined:
            "Better luck next time"
        case .temporaryRoomInvitation:
            "Join to share heart rates"
        }
    }
}
