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
/// **The name is now wrong**; `WatchRelayHeartRateService` is what it should be called.
/// Recorded in `Docs/STATUS.md` and left for its own change, since renaming it here would
/// bury a file move inside a concurrency fix.
///
/// The continuation sits behind a mutex rather than under `@unchecked Sendable`: samples
/// enter from whoever is draining the Watch's message stream and the stream is torn down
/// from the room's exit path, and those are not guaranteed to be the same context.
final class HealthKitHeartRateService: HealthKitServiceProtocol, Sendable {

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
        Log.healthKit.info("Heart rate streaming stopped")
    }
}
