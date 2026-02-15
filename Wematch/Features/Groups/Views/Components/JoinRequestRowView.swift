import SwiftUI

struct JoinRequestRowView: View {
    let request: JoinRequest
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.badge.plus")
                .font(.title3)
                .foregroundStyle(Color.orange.gradient)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.username)
                    .font(WematchTypography.body)
                    .foregroundStyle(WematchTheme.textPrimary)

                Text(request.createdAt.formatted(.relative(presentation: .named)))
                    .font(WematchTypography.caption)
                    .foregroundStyle(WematchTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onAccept()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept request")

                Button {
                    onDecline()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decline request")
            }
        }
        .padding(.vertical, 4)
    }
}
