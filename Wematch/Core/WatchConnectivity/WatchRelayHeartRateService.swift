import Foundation
import Synchronization
import OSLog

/// The phone's heart-rate source: a relay, not a HealthKit client.
///
/// Heart rate is produced by the Watch's workout session and arrives over
/// WatchConnectivity; `yield(heartRate:)` is how it enters this stream. The type used to
/// hold an `HKHealthStore` and request a read it never performed — removed with the
/// iPhone's HealthKit entitlement.
///
/// Named for what it is since decision 0009 was finished (it was `HealthKitHeartRateService`
/// while it still held an `HKHealthStore`); it lives next to `PhoneSessionManager`, the
/// link it relays. `SimulatedHeartRateService` is the simulator's stand-in for it.
///
/// The continuation sits behind a mutex rather than under `@unchecked Sendable`: samples
/// enter from whoever is draining the Watch's message stream and the stream is torn down
/// from the room's exit path, and those are not guaranteed to be the same context.
final class WatchRelayHeartRateService: HealthKitServiceProtocol, Sendable {

    private let streamContinuation = Mutex<AsyncStream<Double>.Continuation?>(nil)

    func startHeartRateStreaming() -> AsyncStream<Double> {
        let (stream, continuation) = AsyncStream<Double>.makeStream()
        streamContinuation.withLock { $0 = continuation }
        return stream
    }

    /// Called with each `.heartRate` message the Watch sends.
    func yield(heartRate: Double) {
        streamContinuation.withLock { _ = $0?.yield(heartRate) }
    }

    func stopHeartRateStreaming() {
        streamContinuation.withLock { continuation in
            continuation?.finish()
            continuation = nil
        }
        Log.watchConnectivity.info("Heart rate relay stopped")
    }
}
