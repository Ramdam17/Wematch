import SwiftUI

struct FriendRequestRowView: View {
    let request: FriendRequest
    let isIncoming: Bool
    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        HStack {
            Image(systemName: isIncoming ? "person.badge.plus" : "paperplane.fill")
                .font(.title3)
                .foregroundStyle(isIncoming ? Color.orange.gradient : Color(hex: "C084FC").gradient)

            VStack(alignment: .leading, spacing: 2) {
                Text(isIncoming ? request.senderUsername : request.receiverUsername)
                    .font(WematchTypography.body)
                    .foregroundStyle(WematchTheme.textPrimary)

                Text(request.createdAt.formatted(.relative(presentation: .named)))
                    .font(WematchTypography.caption)
                    .foregroundStyle(WematchTheme.textSecondary)
            }

            Spacer()

            if isIncoming {
                HStack(spacing: 8) {
                    Button {
                        onAccept?()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accept request")

                    Button {
                        onDecline?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Decline request")
                }
            } else {
                Button {
                    onCancel?()
                } label: {
                    Text("Cancel")
                        .font(WematchTypography.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(Capsule().stroke(.red.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
