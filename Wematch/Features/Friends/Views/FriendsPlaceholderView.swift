import SwiftUI

struct FriendsPlaceholderView: View {
    var body: some View {
        ZStack {
            AnimatedBackground()
            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "67E8F9").gradient)
                    Text("Friends")
                        .font(WematchTypography.title)
                        .foregroundStyle(WematchTheme.textPrimary)
                    Text("Find friends and sync your heartbeats")
                        .font(WematchTypography.body)
                        .foregroundStyle(WematchTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Friends")
    }
}

#Preview {
    NavigationStack {
        FriendsPlaceholderView()
    }
}
