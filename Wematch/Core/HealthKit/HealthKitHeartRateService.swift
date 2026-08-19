import Foundation
import OSLog

/// The phone's heart-rate source: a relay, not a HealthKit client.
///
/// Heart rate is produced by the Watch's workout session and arrives over
/// WatchConnectivity; `yield(heartRate:)` is how it enters this stream. The type used to
/// hold an `HKHealthStore` and request a read it never performed — removed with the
/// iPhone's HealthKit entitlement.
///
/// **The name is now wrong** and is kept only to avoid a rename inside this change;
/// `WatchRelayHeartRateService` is what it should be called.
final class HealthKitHeartRateService: HealthKitServiceProtocol, @unchecked Sendable {

    private var streamContinuation: AsyncStream<Double>.Continuation?

    func startHeartRateStreaming() -> AsyncStream<Double> {
        AsyncStream { continuation in
            self.streamContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                // Stream terminated
            }
        }
    }

    /// Called by PhoneSessionManager when receiving HR from Watch.
    func yield(heartRate: Double) {
        streamContinuation?.yield(heartRate)
    }

    func stopHeartRateStreaming() {
        streamContinuation?.finish()
        streamContinuation = nil
        Log.healthKit.info("Heart rate streaming stopped")
    }
}
