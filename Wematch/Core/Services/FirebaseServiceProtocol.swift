import Foundation

/// A Realtime Database snapshot on its way across a concurrency boundary.
///
/// **`@unchecked Sendable` justification** (plan 1.10). The payload is `[String: Any]`,
/// which the compiler cannot check and which the Firebase SDK fills with bridged
/// Foundation objects (`NSString`, `NSNumber`, `NSDictionary`) — value-like in practice,
/// `Sendable`-audited nowhere. What makes it safe is the lifecycle, not the type: the SDK
/// hands the dictionary over and never touches it again, this wrapper is immutable, and
/// every consumer reads it once, parses it into a checked `Sendable` model
/// (`RoomParticipant`, `TemporaryRoom`) and drops it.
///
/// Giving these payloads real types is the actual fix and belongs with the Firebase
/// decoding, not inside a concurrency step. It exists as a wrapper rather than as
/// `@unchecked` on each service so there is one place to delete when that happens.
nonisolated struct FirebaseSnapshot: @unchecked Sendable {
    let values: [String: Any]

    init(_ values: [String: Any]) {
        self.values = values
    }

    static let empty = FirebaseSnapshot([:])
}

/// Every requirement is `nonisolated`: repositories call these from wherever their own
/// caller happens to be, and a stream is iterated outside any actor. Without it the
/// project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes the whole database layer
/// main-actor bound — network I/O on the actor that draws the plot (plan 1.10).
protocol FirebaseServiceProtocol: Sendable {
    nonisolated func write(path: String, value: [String: any Sendable]) async throws
    /// Throwing on purpose (plan 1.7, audit D2): a Realtime Database listener can be
    /// cancelled by the server — a permission-denied rule is the common case — and a
    /// non-throwing stream turned that into a room where nobody ever speaks.
    nonisolated func observe(path: String) -> AsyncThrowingStream<FirebaseSnapshot, Error>
    /// One-shot read. Three call sites used to fake this by taking the first value of
    /// `observe` behind a 5 s timeout, and reported "empty" for both "nothing there"
    /// and "we never got an answer" (the C5 note in `FirebaseTemporaryRoomRepository`).
    nonisolated func read(path: String) async throws -> FirebaseSnapshot
    /// The client's own view of whether it is talking to the server, from the Realtime
    /// Database's `.info/connected`. The only mechanism that sees a *network* loss: a
    /// listener starved of updates is indistinguishable from a quiet room (plan 1.7,
    /// field-test case S8). Non-throwing — losing the connection is the value, not an error.
    nonisolated func observeConnection() -> AsyncStream<Bool>
    nonisolated func remove(path: String) async throws
    nonisolated func disconnect()
}
