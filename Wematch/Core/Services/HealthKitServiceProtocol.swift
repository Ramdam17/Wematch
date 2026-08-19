import Foundation

/// The phone's heart-rate source. Deliberately has **no authorization surface**: on the
/// phone, heart rate arrives over WatchConnectivity and the Watch owns the HealthKit
/// permission. `requestAuthorization`/`isAuthorized` lived here for a single call site
/// that asked for a read the phone never performed.
protocol HealthKitServiceProtocol: Sendable {
    func startHeartRateStreaming() -> AsyncStream<Double>
    func stopHeartRateStreaming()
}
