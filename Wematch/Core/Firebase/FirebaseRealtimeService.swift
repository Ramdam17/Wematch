import Foundation
import FirebaseDatabase
import OSLog

/// **`@unchecked Sendable` justification** (plan 1.10). Required, not convenience: the
/// Firebase SDK's `Database` and `DatabaseReference` are not `Sendable`-audited, so the
/// single stored `let database` cannot be checked. What makes the type safe is that the
/// property is immutable and every use is a call into the SDK, which serialises its own
/// work on its own queue; this class holds no mutable state of its own. Observer teardown
/// re-derives its reference from `database` and a `String` path rather than capturing a
/// `DatabaseReference` into an escaping closure — that capture is the one thing the
/// compiler *can* see, and it is gone.
nonisolated final class FirebaseRealtimeService: FirebaseServiceProtocol, @unchecked Sendable {

    private let database: Database?

    /// Takes whatever `FirebaseManager` ended up with — possibly nothing.
    init() {
        self.database = FirebaseManager.shared.database
    }

    /// Explicit form. `nil` means *no database*, not "use the shared one": that
    /// conflation made the unavailable path untestable, which is how it stayed
    /// silent for so long (plan 1.7).
    init(database: Database?) {
        self.database = database
    }

    // MARK: - FirebaseServiceProtocol

    func write(path: String, value: [String: any Sendable]) async throws {
        // Was: log and return, i.e. report success for a write that went nowhere
        // (plan 1.7). Every entry point now fails instead.
        guard let database else {
            Log.firebase.error("Firebase not configured — write to \(path) impossible")
            throw RoomError.firebaseUnavailable
        }
        let ref = database.reference().child(path)
        try await ref.setValue(value)
        Log.firebase.debug("Wrote to \(path)")
    }

    func observe(path: String) -> AsyncThrowingStream<FirebaseSnapshot, Error> {
        guard let database else {
            Log.firebase.error("Firebase not configured — observe on \(path) cannot start")
            return AsyncThrowingStream { $0.finish(throwing: RoomError.firebaseUnavailable) }
        }

        let ref = database.reference().child(path)

        return AsyncThrowingStream { continuation in
            // `withCancel` is the half that was missing: without it a listener the
            // server refuses (rules change, token expiry) simply never fires again,
            // and the room silently freezes instead of saying so.
            let handle = ref.observe(.value) { snapshot in
                guard let value = snapshot.value as? [String: Any] else {
                    continuation.yield(.empty)
                    return
                }
                continuation.yield(FirebaseSnapshot(value))
            } withCancel: { error in
                Log.firebase.error("Observation of \(path) cancelled: \(error.localizedDescription)")
                continuation.finish(throwing: error)
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                self?.removeObserver(handle, atPath: path)
            }
        }
    }

    func read(path: String) async throws -> FirebaseSnapshot {
        guard let database else {
            Log.firebase.error("Firebase not configured — read of \(path) cannot run")
            throw RoomError.firebaseUnavailable
        }
        let snapshot = try await database.reference().child(path).getData()
        return FirebaseSnapshot(snapshot.value as? [String: Any] ?? [:])
    }

    func observeConnection() -> AsyncStream<Bool> {
        guard let database else {
            // Nothing to connect to; say so once rather than leaving the caller to
            // assume health from silence.
            return AsyncStream { continuation in
                continuation.yield(false)
                continuation.finish()
            }
        }

        // `.info/connected` is a client-side pseudo-path: the SDK maintains it locally
        // and it is the documented way to observe presence of the connection itself.
        let ref = database.reference(withPath: ".info/connected")

        return AsyncStream { continuation in
            let handle = ref.observe(.value) { snapshot in
                continuation.yield(snapshot.value as? Bool ?? false)
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.removeConnectionObserver(handle)
            }
        }
    }

    /// Teardown for `observe(path:)`. Takes the path rather than the reference so that
    /// nothing non-`Sendable` is captured into the escaping termination closure.
    private func removeObserver(_ handle: DatabaseHandle, atPath path: String) {
        database?.reference().child(path).removeObserver(withHandle: handle)
    }

    /// Same, for the `.info/connected` pseudo-path.
    private func removeConnectionObserver(_ handle: DatabaseHandle) {
        database?.reference(withPath: ".info/connected").removeObserver(withHandle: handle)
    }

    func remove(path: String) async throws {
        guard let database else {
            Log.firebase.error("Firebase not configured — remove at \(path) impossible")
            throw RoomError.firebaseUnavailable
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
