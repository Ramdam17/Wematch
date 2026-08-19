import Foundation
import Synchronization
import OSLog

/// Generates realistic simulated heart rate data at ~1 Hz for development on Simulator.
final class SimulatedHeartRateService: HealthKitServiceProtocol, Sendable {

    private let streamTask = Mutex<Task<Void, Never>?>(nil)

    func startHeartRateStreaming() -> AsyncStream<Double> {
        let (stream, continuation) = AsyncStream<Double>.makeStream()

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

        streamTask.withLock { $0 = task }
        continuation.onTermination = { _ in task.cancel() }

        return stream
    }

    /// No-op: this source produces its own samples and has no Watch behind it. Present
    /// because the protocol carries it, not because the simulator relays anything.
    func yield(heartRate: Double) {}

    func stopHeartRateStreaming() {
        streamTask.withLock { task in
            task?.cancel()
            task = nil
        }
        Log.healthKit.info("[Simulated] Heart rate streaming stopped")
    }
}
