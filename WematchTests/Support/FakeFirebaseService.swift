import Foundation
@testable import Wematch

/// In-memory FirebaseServiceProtocol recording every write/remove path and
/// every observe-stream termination — lets tests verify cleanup chains
/// (E1 index removal, C2 listener teardown) end to end.
/// **`@unchecked Sendable` justification** (plan 1.10): test-only, single-threaded XCTest
/// access. The observe-termination record is written from the stream's termination
/// handler, serialised behind the `await` that drains it.
final class FakeFirebaseService: FirebaseServiceProtocol, @unchecked Sendable {
    var storage: [String: [String: any Sendable]] = [:]
    var removedPaths: [String] = []
    var observeTerminations: [String] = []

    /// false (default): observe yields one snapshot then finishes — for
    /// one-shot read patterns. true: the stream stays open until the
    /// consumer cancels — for listener-lifecycle tests.
    var keepObserveOpen = false

    func write(path: String, value: [String: any Sendable]) async throws {
        storage[path] = value
    }

    /// Thrown by the observe stream instead of yielding — the permission-denied case.
    var observeError: Error?

    func read(path: String) async throws -> FirebaseSnapshot {
        if let readError { throw readError }
        return FirebaseSnapshot(storage[path] ?? [:])
    }

    /// Thrown by `read`.
    var readError: Error?

    func observe(path: String) -> AsyncThrowingStream<FirebaseSnapshot, Error> {
        let snapshot = FirebaseSnapshot(storage[path] ?? [:])
        let keepOpen = keepObserveOpen
        let error = observeError
        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.observeTerminations.append(path)
            }
            continuation.yield(snapshot)
            if !keepOpen {
                continuation.finish()
            }
        }
    }

    /// Connection values delivered in order; empty means "connected throughout".
    var connectionUpdates: [Bool] = []

    func observeConnection() -> AsyncStream<Bool> {
        let updates = connectionUpdates
        return AsyncStream { continuation in
            for value in updates { continuation.yield(value) }
            continuation.finish()
        }
    }

    func remove(path: String) async throws {
        callLog.append("remove:\(path)")
        removedPaths.append(path)
        storage[path] = nil
    }

    var armedPaths: [String] = []
    var disarmedPaths: [String] = []
    /// Thrown by `armDisconnectRemoval` — the server refusing the hook.
    var armError: Error?
    /// Every path-touching call, in order — for tests about sequencing.
    var callLog: [String] = []

    func armDisconnectRemoval(path: String) async throws {
        callLog.append("arm:\(path)")
        if let armError { throw armError }
        armedPaths.append(path)
    }

    func disarmDisconnectRemoval(path: String) async throws {
        callLog.append("disarm:\(path)")
        disarmedPaths.append(path)
    }

    func disconnect() {}
}
