import Foundation
import FirebaseCore
import FirebaseDatabase
import OSLog

final class FirebaseManager: @unchecked Sendable {
    static let shared = FirebaseManager()

    private(set) var database: Database?

    private init() {}

    func configure() {
        guard FirebaseApp.app() == nil else {
            Log.firebase.info("Firebase already configured")
            return
        }
        FirebaseApp.configure()
        database = Database.database()
        Log.firebase.info("Firebase configured successfully")
    }
}
