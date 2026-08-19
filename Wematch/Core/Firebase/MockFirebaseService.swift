import Foundation
import OSLog

/// In-memory Firebase service for development without GoogleService-Info.plist.
///
/// **`@unchecked Sendable` justification** (plan 1.10): the two dictionaries below are
/// mutable and unprotected. It is `#if DEBUG`-only substitution — release builds fail
/// loudly instead of serving a room made of local state (plan 1.7) — and it is driven
/// from the main actor by a single developer on a simulator. Locking it would buy
/// nothing real and would make the fake less readable than the thing it fakes.
nonisolated final class MockFirebaseService: FirebaseServiceProtocol, @unchecked Sendable {

    private var storage: [String: [String: Any]] = [:]
    private var continuations: [String: AsyncThrowingStream<FirebaseSnapshot, Error>.Continuation] = [:]

    func write(path: String, value: [String: any Sendable]) async throws {
        storage[path] = value
        Log.firebase.debug("[Mock] Wrote to \(path): \(value.keys.joined(separator: ", "))")

        // Notify observers on parent path
        let parentPath = path.components(separatedBy: "/").dropLast().joined(separator: "/")
        notifyObservers(for: parentPath)
        notifyObservers(for: path)
    }

    func observe(path: String) -> AsyncThrowingStream<FirebaseSnapshot, Error> {
        AsyncThrowingStream { continuation in
            self.continuations[path] = continuation

            // Yield current state
            let snapshot = self.buildSnapshot(for: path)
            continuation.yield(FirebaseSnapshot(snapshot))

            continuation.onTermination = { @Sendable _ in
                // Cleanup handled by disconnect()
            }
        }
    }

    func read(path: String) async throws -> FirebaseSnapshot {
        FirebaseSnapshot(buildSnapshot(for: path))
    }

    func observeConnection() -> AsyncStream<Bool> {
        // The in-memory store is always "reachable".
        AsyncStream { continuation in
            continuation.yield(true)
            continuation.finish()
        }
    }

    func remove(path: String) async throws {
        storage = storage.filter { key, _ in
            !key.hasPrefix(path)
        }
        Log.firebase.debug("[Mock] Removed \(path)")

        let parentPath = path.components(separatedBy: "/").dropLast().joined(separator: "/")
        notifyObservers(for: parentPath)
    }

    /// The in-memory store has no connection to lose; there is nothing to arm.
    func armDisconnectRemoval(path: String) async throws {
        Log.firebase.debug("[Mock] onDisconnect removal requested for \(path) — no-op")
    }

    func disarmDisconnectRemoval(path: String) async throws {}

    func disconnect() {
        for (_, continuation) in continuations {
            continuation.finish()
        }
        continuations.removeAll()
        Log.firebase.info("[Mock] Disconnected")
    }

    // MARK: - Private

    private func notifyObservers(for path: String) {
        guard let continuation = continuations[path] else { return }
        continuation.yield(FirebaseSnapshot(buildSnapshot(for: path)))
    }

    private func buildSnapshot(for path: String) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in storage {
            if key == path {
                result = value
            } else if key.hasPrefix(path + "/") {
                let remainder = String(key.dropFirst(path.count + 1))
                let childKey = remainder.components(separatedBy: "/").first ?? remainder
                result[childKey] = value
            }
        }
        return result
    }
}
