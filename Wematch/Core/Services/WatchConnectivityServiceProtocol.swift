import Foundation

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
    func send(message: [String: Any]) async throws
    var receivedMessages: AsyncStream<[String: Any]> { get }
    var isReachable: Bool { get }
}
