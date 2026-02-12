import Foundation

protocol WatchConnectivityServiceProtocol: Sendable {
    func activate()
    func send(message: [String: Any]) async throws
    var receivedMessages: AsyncStream<[String: Any]> { get }
    var isReachable: Bool { get }
}
