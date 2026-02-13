import Foundation
import OSLog

/// Generates realistic simulated heart rate data at ~1 Hz for development on Simulator.
final class SimulatedHeartRateService: HealthKitServiceProtocol, @unchecked Sendable {

    private(set) var isAuthorized = true
    private var streamTask: Task<Void, Never>?

    func requestAuthorization() async throws {
        // Always authorized in simulation
        Log.healthKit.info("[Simulated] HealthKit authorization granted (simulated)")
    }

    func startHeartRateStreaming() -> AsyncStream<Double> {
        AsyncStream { continuation in
            let task = Task {
                var hr = 72.0
                Log.healthKit.info("[Simulated] Heart rate streaming started")

                while !Task.isCancelled {
                    // Random walk with mean reversion toward 75 BPM
                    let drift = (75.0 - hr) * 0.05
                    let noise = Double.random(in: -2.0...2.0)
                    hr = max(50, min(120, hr + drift + noise))

                    continuation.yield(hr.rounded())
                    try? await Task.sleep(for: .seconds(1))
                }
                continuation.finish()
            }

            self.streamTask = task

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func stopHeartRateStreaming() {
        streamTask?.cancel()
        streamTask = nil
        Log.healthKit.info("[Simulated] Heart rate streaming stopped")
    }
}
