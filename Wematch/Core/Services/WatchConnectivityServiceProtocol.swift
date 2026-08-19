import Foundation
import WematchCore

/// What can go wrong on the phone→Watch link, named so a caller can react rather than
/// read a log (plan 1.7, D1).
enum WatchConnectivityError: LocalizedError {
    /// The Watch app is not running, or the two devices are out of range.
    case watchUnreachable

    var errorDescription: String? {
        switch self {
        case .watchUnreachable:
            "Can't reach your Watch. Open Wematch on it and try again."
        }
    }
}

protocol WatchConnectivityServiceProtocol: Sendable {
    func activate()

    /// Delivers a message and waits for the peer to acknowledge it. Throws
    /// `WatchConnectivityError.watchUnreachable` rather than returning as if it had sent.
    func send(_ message: WatchMessage) async throws

    /// Best effort, no acknowledgement — for the ~1 Hz plot feed, where a dropped frame
    /// is replaced by the next one a second later and awaiting a reply per frame would
    /// queue the link up behind itself.
    func sendWithoutAcknowledgement(_ message: WatchMessage)

    /// A fresh stream per caller, all fed the same messages.
    ///
    /// A method, not the property it used to be: reading it twice used to hand two
    /// consumers one `AsyncStream`, where the second silently starves the first. The
    /// Watch app has two independent readers (the room and the dashboard, which outlives
    /// it), so one stream was never enough.
    func messages() -> AsyncStream<WatchMessage>

    var isReachable: Bool { get }
}
