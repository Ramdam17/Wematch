import SwiftUI

struct InboxPlaceholderView: View {
    var body: some View {
        ZStack {
            AnimatedBackground()
            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "FBBF24").gradient)
                    Text("Inbox")
                        .font(WematchTypography.title)
                        .foregroundStyle(WematchTheme.textPrimary)
                    Text("Notifications and requests will appear here")
                        .font(WematchTypography.body)
                        .foregroundStyle(WematchTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Inbox")
    }
}

#Preview {
    NavigationStack {
        InboxPlaceholderView()
    }
}
