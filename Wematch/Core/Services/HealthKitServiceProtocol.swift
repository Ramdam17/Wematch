import Foundation

/// The phone's heart-rate source. Deliberately has **no authorization surface**: on the
/// phone, heart rate arrives over WatchConnectivity and the Watch owns the HealthKit
/// permission. `requestAuthorization`/`isAuthorized` lived here for a single call site
/// that asked for a read the phone never performed.
protocol HealthKitServiceProtocol: Sendable {
    func startHeartRateStreaming() -> AsyncStream<Double>
    func stopHeartRateStreaming()

    /// Pushes one sample into the stream.
    ///
    /// On the protocol rather than on the concrete relay because `RoomViewModel` used to
    /// reach the real service by downcasting the injected protocol
    /// (`healthKitService as? HealthKitHeartRateService`) — the exact pattern `CLAUDE.md`
    /// forbids and the audit named as the root cause of half its findings. A protocol
    /// that did not cover a need is extended, never worked around (plan 1.10).
    ///
    /// The simulator's source generates its own samples and ignores this.
    func yield(heartRate: Double)
}
