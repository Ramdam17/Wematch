import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: WematchTheme.paddingLarge) {
                Spacer()

                HeartIcon(color: Color(hex: "FF6B9D"), size: 80, showGlow: true)

                VStack(spacing: WematchTheme.paddingSmall) {
                    Text("Wematch")
                        .font(WematchTypography.largeTitle)
                        .foregroundStyle(WematchTheme.textPrimary)

                    Text("Sync your hearts")
                        .font(WematchTypography.body)
                        .foregroundStyle(WematchTheme.textSecondary)
                }

                Spacer()

                VStack(spacing: WematchTheme.paddingMedium) {
                    SignInWithAppleButton(.signIn, onRequest: { _ in },
                                         onCompletion: { _ in })
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .fill(Color.clear)
                                .contentShape(Capsule())
                                .onTapGesture {
                                    Task { await authManager.signInWithApple() }
                                }
                        }

                    Label("Your data is safe & private", systemImage: "lock.shield.fill")
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
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
    SignInView()
        .environment(AuthenticationManager())
}
