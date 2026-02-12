import SwiftUI

struct RoomsPlaceholderView: View {
    var body: some View {
        ZStack {
            AnimatedBackground()
            GlassCard {
                VStack(spacing: 16) {
                    HeartIcon(color: Color(hex: "FF6B9D"), size: 48, showGlow: true)
                    Text("Rooms")
                        .font(WematchTypography.title)
                        .foregroundStyle(WematchTheme.textPrimary)
                    Text("Your heart rate rooms will appear here")
                        .font(WematchTypography.body)
                        .foregroundStyle(WematchTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Rooms")
    }
}

#Preview {
    NavigationStack {
        RoomsPlaceholderView()
    }
}
