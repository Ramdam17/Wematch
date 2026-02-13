import SwiftUI

struct UsernamePickerView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        ZStack {
            WematchTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: WematchTheme.paddingLarge) {
                Spacer()

                VStack(spacing: WematchTheme.paddingSmall) {
                    Text("Your username")
                        .font(WematchTypography.title)
                        .foregroundStyle(WematchTheme.textPrimary)

                    Text("This is how others will see you")
                        .font(WematchTypography.body)
                        .foregroundStyle(WematchTheme.textSecondary)
                }

                GlassCard(cornerRadius: WematchTheme.cornerRadiusLarge,
                          padding: WematchTheme.paddingLarge) {
                    VStack(spacing: WematchTheme.paddingMedium) {
                        Text(authManager.generatedUsername)
                            .font(WematchTypography.title2)
                            .foregroundStyle(WematchTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Button {
                            authManager.shuffleUsername()
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .font(WematchTypography.callout)
                                .foregroundStyle(Color(hex: "C084FC"))
                        }
                    }
                }
                .padding(.horizontal, WematchTheme.paddingMedium)

                Spacer()

                GradientButton("Confirm") {
                    Task { await authManager.confirmUsername() }
                }

                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, WematchTheme.paddingLarge)

            if authManager.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(WematchTheme.textPrimary)
                    .scaleEffect(1.5)
            }
        }
        .alert("Error", isPresented: .init(
            get: { authManager.error != nil },
            set: { if !$0 { authManager.error = nil } }
        )) {
            Button("OK") { authManager.error = nil }
        } message: {
            Text(authManager.error?.localizedDescription ?? "")
        }
    }
}

#Preview {
    let manager = AuthenticationManager()
    UsernamePickerView()
        .environment(manager)
}
