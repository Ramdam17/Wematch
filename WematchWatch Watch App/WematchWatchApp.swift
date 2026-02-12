import SwiftUI
import os

@main
struct WematchWatchApp: App {
    private let logger = Logger(subsystem: "com.remyramadour.Wematch.watchkitapp", category: "general")

    init() {
        WatchSessionManager.shared.activate()
        logger.info("WematchWatch app launched")
    }

    var body: some Scene {
        WindowGroup {
            WatchPlaceholderView()
        }
    }
}
