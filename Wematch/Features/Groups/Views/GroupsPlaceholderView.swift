import SwiftUI

struct GroupsPlaceholderView: View {
    var body: some View {
        ZStack {
            AnimatedBackground()
            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "C084FC").gradient)
                    Text("Groups")
                        .font(WematchTypography.title)
                        .foregroundStyle(WematchTheme.textPrimary)
                    Text("Create or join a group to start syncing")
                        .font(WematchTypography.body)
                        .foregroundStyle(WematchTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Groups")
    }
}

#Preview {
    NavigationStack {
        GroupsPlaceholderView()
    }
}
