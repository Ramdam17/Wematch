import Foundation
import FirebaseCore
import FirebaseDatabase
import Synchronization
import OSLog

/// Holds the configured `Database`, or nothing.
///
/// The handle used to be a plain `var` under `@unchecked Sendable`: written once by
/// `configure()` at launch and read afterwards from every repository, on whatever context
/// happened to be running. In practice the write lands before the first read, but "in
/// practice" is not a memory model — and it is the kind of assumption that holds until the
/// first slow launch. A mutex makes it checkable, and drops the `@unchecked` (plan 1.10).
nonisolated final class FirebaseManager: Sendable {
    static let shared = FirebaseManager()

    private let storedDatabase = Mutex<Database?>(nil)

    var database: Database? { storedDatabase.withLock { $0 } }

    private init() {}

    func configure() {
        guard FirebaseApp.app() == nil else {
            Log.firebase.info("Firebase already configured")
            return
        }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            Log.firebase.warning("GoogleService-Info.plist not found — Firebase disabled")
            return
        }

        FirebaseApp.configure()
        storedDatabase.withLock { $0 = Database.database() }
        Log.firebase.info("Firebase configured successfully")
    }
}
