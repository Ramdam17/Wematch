import Foundation

protocol HealthKitServiceProtocol: Sendable {
    func requestAuthorization() async throws
    func startHeartRateStreaming() -> AsyncStream<Double>
    func stopHeartRateStreaming()
    var isAuthorized: Bool { get }
}
