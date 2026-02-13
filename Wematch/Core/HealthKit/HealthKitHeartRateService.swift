import Foundation
import HealthKit
import OSLog

final class HealthKitHeartRateService: HealthKitServiceProtocol, @unchecked Sendable {

    private let healthStore = HKHealthStore()
    private var streamContinuation: AsyncStream<Double>.Continuation?
    private(set) var isAuthorized = false

    func requestAuthorization() async throws {
        let heartRateType = HKQuantityType(.heartRate)
        try await healthStore.requestAuthorization(toShare: [], read: [heartRateType])
        isAuthorized = true
        Log.healthKit.info("HealthKit heart rate authorization granted")
    }

    func startHeartRateStreaming() -> AsyncStream<Double> {
        // On iPhone, HR data arrives via WatchConnectivity, not direct HealthKit query.
        // This stream is populated externally by calling `yield(_:)`.
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
