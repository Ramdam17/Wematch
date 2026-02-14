import SwiftUI

struct DashboardPlaceholderView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 32) {
                // Pulsing heart
                HeartIcon(color: Color(hex: "F472B6"), size: 64, showGlow: true)
                    .scaleEffect(isPulsing ? 1.15 : 0.95)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                GlassCard {
                    VStack(spacing: 12) {
                        Text("Dashboard")
                            .font(WematchTypography.title)
                            .foregroundStyle(WematchTheme.textPrimary)

                        Text("Coming Soon")
                            .font(WematchTypography.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B9D"), Color(hex: "C084FC"), Color(hex: "67E8F9")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Track your sync stats, session history, and connection streaks — all in one place.")
                            .font(WematchTypography.body)
                            .foregroundStyle(WematchTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                // Teaser feature list
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(icon: "clock.fill", text: "Session history & duration")
                        featureRow(icon: "heart.fill", text: "Sync events & streaks")
                        featureRow(icon: "chart.bar.fill", text: "Personal metrics & trends")
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Dashboard")
        .onAppear { isPulsing = true }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "C084FC").gradient)
                .frame(width: 24)
            Text(text)
                .font(WematchTypography.callout)
                .foregroundStyle(WematchTheme.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardPlaceholderView()
    }
}
