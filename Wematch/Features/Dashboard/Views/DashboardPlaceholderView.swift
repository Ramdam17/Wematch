import SwiftUI

struct DashboardPlaceholderView: View {
    var body: some View {
        ZStack {
            AnimatedBackground()
            GlassCard {
                VStack(spacing: 16) {
                    HeartIcon(color: Color(hex: "F472B6"), size: 48, showGlow: true)
                    Text("Dashboard")
                        .font(WematchTypography.title)
                        .foregroundStyle(WematchTheme.textPrimary)
                    Text("Coming Soon")
                        .font(WematchTypography.title3)
                        .foregroundStyle(WematchTheme.textSecondary)
                    Text("Track your sync stats, streaks, and more")
                        .font(WematchTypography.body)
                        .foregroundStyle(WematchTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }
}

#Preview {
    NavigationStack {
        DashboardPlaceholderView()
    }
}
