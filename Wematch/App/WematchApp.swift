import SwiftUI
import OSLog

@main
struct WematchApp: App {
    @State private var authManager: AuthenticationManager

    init() {
        // Firebase MUST be configured before anything Firebase-adjacent is
        // built (stored-property defaults would run first) — avoids the
        // I-COR000003 "not yet configured" boot warning.
        FirebaseManager.shared.configure()
        PhoneSessionManager.shared.activate()
        _authManager = State(initialValue: AuthenticationManager())
        Log.general.info("Wematch app launched")
    }

    var body: some Scene {
        WindowGroup {
            SwiftUI.Group {
                switch authManager.authState {
                case .unknown:
                    ZStack {
                        AnimatedBackground()
                        LoadingState(message: "Restoring your session…")
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                wakeUpWatchApp()
            }
        }
    }

    // MARK: - Watch Connectivity

    /// Sends a wake-up message to the Watch app when iPhone app becomes active.
    /// This allows the Watch app to launch automatically, similar to Spotify.
    private func wakeUpWatchApp() {
        Task {
            // Wait a bit to ensure WCSession is fully activated before sending messages
            try? await Task.sleep(for: .milliseconds(500))

            do {
                try await PhoneSessionManager.shared.send(message: ["type": "appLaunched"])
                Log.general.debug("Wake-up message sent to Watch")
            } catch {
                // Watch may not be reachable — this is expected if Watch is off/disconnected
                Log.general.debug("Watch wake-up message failed (expected if Watch not connected): \(error.localizedDescription)")
            }
        }
    }
}
