import Foundation

protocol FirebaseServiceProtocol: Sendable {
    func write(path: String, value: [String: any Sendable]) async throws
    /// Throwing on purpose (plan 1.7, audit D2): a Realtime Database listener can be
    /// cancelled by the server — a permission-denied rule is the common case — and a
    /// non-throwing stream turned that into a room where nobody ever speaks.
    func observe(path: String) -> AsyncThrowingStream<[String: Any], Error>
    /// One-shot read. Three call sites used to fake this by taking the first value of
    /// `observe` behind a 5 s timeout, and reported "empty" for both "nothing there"
    /// and "we never got an answer" (the C5 note in `FirebaseTemporaryRoomRepository`).
    func read(path: String) async throws -> [String: Any]
    /// The client's own view of whether it is talking to the server, from the Realtime
    /// Database's `.info/connected`. The only mechanism that sees a *network* loss: a
    /// listener starved of updates is indistinguishable from a quiet room (plan 1.7,
    /// field-test case S8). Non-throwing — losing the connection is the value, not an error.
    func observeConnection() -> AsyncStream<Bool>
    func remove(path: String) async throws
    func disconnect()
}
