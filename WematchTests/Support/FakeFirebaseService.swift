import Foundation
@testable import Wematch

/// In-memory FirebaseServiceProtocol recording every write/remove path and
/// every observe-stream termination — lets tests verify cleanup chains
/// (E1 index removal, C2 listener teardown) end to end.
final class FakeFirebaseService: FirebaseServiceProtocol, @unchecked Sendable {
    // Test-only fake: single-threaded XCTest access (observe termination is
    // recorded from the stream's termination handler, serialized by await).
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

    func read(path: String) async throws -> [String: Any] {
        if let readError { throw readError }
        return storage[path] ?? [:]
    }

    /// Thrown by `read`.
    var readError: Error?

    func observe(path: String) -> AsyncThrowingStream<[String: Any], Error> {
        let snapshot = storage[path] ?? [:]
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
        removedPaths.append(path)
        storage[path] = nil
    }

    func disconnect() {}
}
