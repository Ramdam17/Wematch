import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        ZStack {
            AnimatedBackground()
            GlassCard {
                VStack(spacing: 16) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "A78BFA").gradient)
                    Text("Settings")
                        .font(WematchTypography.title)
                        .foregroundStyle(WematchTheme.textPrimary)
                    Text("Account and preferences")
                        .font(WematchTypography.body)
                        .foregroundStyle(WematchTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView()
    }
}
