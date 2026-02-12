import SwiftUI
import OSLog

@main
struct WematchApp: App {
    @State private var authManager = AuthenticationManager()

    init() {
        FirebaseManager.shared.configure()
        PhoneSessionManager.shared.activate()
        Log.general.info("Wematch app launched")
    }

    var body: some Scene {
        WindowGroup {
            SwiftUI.Group {
                switch authManager.authState {
                case .unknown:
                    ZStack {
                        AnimatedBackground()
                        ProgressView()
                            .tint(WematchTheme.textPrimary)
                    }
                case .signedOut:
                    SignInView()
                case .needsUsername:
                    UsernamePickerView()
                case .signedIn:
                    MainTabView()
                }
            }
            .environment(authManager)
            .environment(\.featureFlagProvider, LocalFeatureFlagProvider())
            .task { await authManager.restoreSession() }
        }
    }
}
