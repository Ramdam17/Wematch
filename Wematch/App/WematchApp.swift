import SwiftUI
import OSLog

@main
struct WematchApp: App {
    init() {
        FirebaseManager.shared.configure()
        PhoneSessionManager.shared.activate()
        Log.general.info("Wematch app launched")
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.featureFlagProvider, LocalFeatureFlagProvider())
        }
    }
}
