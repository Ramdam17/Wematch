import HealthKit
import os

final class WatchHeartRateManager: NSObject, @unchecked Sendable {

    private let healthStore = HKHealthStore()
    private let logger = Logger(
        subsystem: "com.remyramadour.Wematch.watchkitapp",
        category: "healthkit"
    )

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var streamContinuation: AsyncStream<Double>.Continuation?

    /// Whether authorization has been *asked for* — not whether it was granted.
    /// `requestAuthorization` returns normally on a denial, so granted-ness is not
    /// knowable here; see `WatchHeartRateStatus`. Naming this `isAuthorized` is
    /// what made the denial path silent.
    private(set) var hasRequestedAuthorization = false
    private(set) var isStreaming = false

    // MARK: - Authorization

    func requestAuthorization() async throws {
        let heartRateType = HKQuantityType(.heartRate)
        let workoutType = HKObjectType.workoutType()

        // Throws on system errors only (missing usage key, HealthKit unavailable).
        // A user tapping "Don't Allow" returns normally — WWDC 2020-10664.
        try await healthStore.requestAuthorization(
            toShare: [workoutType],
            read: [heartRateType]
        )
        hasRequestedAuthorization = true
        logger.info("HealthKit authorization requested (grant status unknowable)")
    }

    // MARK: - Workout Session

    func startStreaming() -> AsyncStream<Double> {
        AsyncStream { continuation in
            self.streamContinuation = continuation

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in
                    self?.stopStreaming()
                }
            }

            Task {
                do {
                    try await self.startWorkoutSession()
                } catch {
                    self.logger.error("Failed to start workout session: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }

    func stopStreaming() {
        guard isStreaming else { return }

        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, error in
            if let error {
                self?.logger.error("Failed to end builder collection: \(error.localizedDescription)")
            }
            self?.builder?.finishWorkout { _, error in
                if let error {
                    self?.logger.error("Failed to finish workout: \(error.localizedDescription)")
                }
            }
        }

        session = nil
        builder = nil
        isStreaming = false
        streamContinuation?.finish()
        streamContinuation = nil
        logger.info("Workout session stopped")
    }

    // MARK: - Private

    private func startWorkoutSession() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()

        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )

        session.delegate = self
        builder.delegate = self

        self.session = session
        self.builder = builder

        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        isStreaming = true
        logger.info("Workout session started — streaming HR")
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchHeartRateManager: HKWorkoutSessionDelegate {

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        logger.info("Workout state: \(String(describing: fromState)) → \(String(describing: toState))")

        if toState == .ended {
            isStreaming = false
        }
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        logger.error("Workout session failed: \(error.localizedDescription)")
        stopStreaming()
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchHeartRateManager: HKLiveWorkoutBuilderDelegate {

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Not used — we only care about HR samples
    }

    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let heartRateType = HKQuantityType(.heartRate)

        guard collectedTypes.contains(heartRateType) else { return }

        guard let statistics = workoutBuilder.statistics(for: heartRateType),
              let value = statistics.mostRecentQuantity() else {
            return
        }

        let hr = value.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        // Heart rate is health data — never in cleartext logs (audit B5).
        logger.debug("HR: \(hr, format: .fixed(precision: 0), privacy: .private) BPM")
        streamContinuation?.yield(hr.rounded())
    }
}
