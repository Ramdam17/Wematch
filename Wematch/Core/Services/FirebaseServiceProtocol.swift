import Foundation

protocol FirebaseServiceProtocol: Sendable {
    func write(path: String, value: [String: any Sendable]) async throws
    func observe(path: String) -> AsyncStream<[String: Any]>
    func remove(path: String) async throws
    func disconnect()
}
