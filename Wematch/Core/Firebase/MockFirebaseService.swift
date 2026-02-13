import Foundation
import OSLog

/// In-memory Firebase service for development without GoogleService-Info.plist.
final class MockFirebaseService: FirebaseServiceProtocol, @unchecked Sendable {

    private var storage: [String: [String: Any]] = [:]
    private var continuations: [String: AsyncStream<[String: Any]>.Continuation] = [:]

    func write(path: String, value: [String: any Sendable]) async throws {
        storage[path] = value
        Log.firebase.debug("[Mock] Wrote to \(path): \(value.keys.joined(separator: ", "))")

        // Notify observers on parent path
        let parentPath = path.components(separatedBy: "/").dropLast().joined(separator: "/")
        notifyObservers(for: parentPath)
        notifyObservers(for: path)
    }

    func observe(path: String) -> AsyncStream<[String: Any]> {
        AsyncStream { continuation in
            self.continuations[path] = continuation

            // Yield current state
            let snapshot = self.buildSnapshot(for: path)
            continuation.yield(snapshot)

            continuation.onTermination = { @Sendable _ in
                // Cleanup handled by disconnect()
            }
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
        let snapshot = buildSnapshot(for: path)
        continuation.yield(snapshot)
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
