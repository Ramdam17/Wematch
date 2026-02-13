import Foundation
import FirebaseDatabase
import OSLog

final class FirebaseRealtimeService: FirebaseServiceProtocol, @unchecked Sendable {

    private let database: Database?

    init(database: Database? = nil) {
        self.database = database ?? FirebaseManager.shared.database
    }

    // MARK: - FirebaseServiceProtocol

    func write(path: String, value: [String: any Sendable]) async throws {
        guard let database else {
            Log.firebase.warning("Firebase not configured — write to \(path) skipped")
            return
        }
        let ref = database.reference().child(path)
        try await ref.setValue(value)
        Log.firebase.debug("Wrote to \(path)")
    }

    func observe(path: String) -> AsyncStream<[String: Any]> {
        guard let database else {
            Log.firebase.warning("Firebase not configured — observe on \(path) skipped")
            return AsyncStream { $0.finish() }
        }

        let ref = database.reference().child(path)

        return AsyncStream { continuation in
            let handle = ref.observe(.value) { snapshot in
                guard let value = snapshot.value as? [String: Any] else {
                    continuation.yield([:])
                    return
                }
                continuation.yield(value)
            }

            continuation.onTermination = { @Sendable _ in
                ref.removeObserver(withHandle: handle)
            }
        }
    }

    func remove(path: String) async throws {
        guard let database else {
            Log.firebase.warning("Firebase not configured — remove at \(path) skipped")
            return
        }
        let ref = database.reference().child(path)
        try await ref.removeValue()
        Log.firebase.debug("Removed \(path)")
    }

    func disconnect() {
        guard let database else { return }
        database.goOffline()
        Log.firebase.info("Firebase disconnected")
    }

    // MARK: - Room-specific Helpers

    func setOnDisconnectRemove(path: String) {
        guard let database else { return }
        database.reference().child(path).onDisconnectRemoveValue()
        Log.firebase.debug("Set onDisconnect remove for \(path)")
    }

    func cancelOnDisconnect(path: String) {
        guard let database else { return }
        database.reference().child(path).cancelDisconnectOperations()
    }
}
