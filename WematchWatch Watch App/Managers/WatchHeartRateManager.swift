import HealthKit
import Synchronization
import os
import WematchCore

/// Owns the workout session that produces heart rate, and hands it out as a stream.
///
/// **Isolation** (plan 1.10, C3). The type used to be `@unchecked Sendable` with five
/// mutable properties written from three places: the main actor, HealthKit's delegate
/// queue, and an `onTermination` callback on whatever thread finished the stream. The
/// split now follows what each piece of state is actually for:
///
/// - the workout session, the builder and the two flags are `@MainActor`. They are read by
///   `WatchRoomViewModel` inside a `body`, and nothing needs them from the delegate queue —
///   `didCollectDataOf` is handed the builder it should ask;
/// - the stream continuation sits behind a mutex, because heart-rate samples must reach it
///   from the delegate queue **synchronously and in order**. Hopping them onto the main
///   actor with a `Task` would put the plot's own signal at the mercy of task ordering.
@MainActor
final class WatchHeartRateManager: NSObject {

    private let healthStore = HKHealthStore()
    /// `nonisolated`: the HealthKit delegate queue logs through it too.
    private nonisolated let logger = Logger(
        subsystem: "com.remyramadour.Wematch.watchkitapp",
        category: "healthkit"
    )

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    /// Reachable from the HealthKit delegate queue; see the note above.
    private nonisolated let streamContinuation = Mutex<AsyncStream<Double>.Continuation?>(nil)

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
        let (stream, continuation) = AsyncStream<Double>.makeStream()
        streamContinuation.withLock { $0 = continuation }

        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopStreaming()
            }
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await startWorkoutSession()
            } catch {
                logger.error("Failed to start workout session: \(error.localizedDescription)")
                continuation.finish()
            }
        }

        return stream
    }

    func stopStreaming() {
        guard isStreaming else { return }

        session?.end()

        // Both completions land on an arbitrary queue and only log, so they capture the
        // builder they need rather than reading it back off the main actor after this
        // method has already cleared it.
        if let builder {
            builder.endCollection(withEnd: Date()) { [logger] _, error in
                if let error {
                    logger.error("Failed to end builder collection: \(error.localizedDescription)")
                }
                builder.finishWorkout { [logger] _, error in
                    if let error {
                        logger.error("Failed to finish workout: \(error.localizedDescription)")
                    }
                }
            }
        }

        session = nil
        builder = nil
        isStreaming = false
        streamContinuation.withLock { continuation in
            continuation?.finish()
            continuation = nil
        }
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

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        let transition = "\(String(describing: fromState)) → \(String(describing: toState))"
        let ended = toState == .ended

        Task { @MainActor [weak self] in
            self?.logger.info("Workout state: \(transition, privacy: .public)")
            if ended {
                self?.isStreaming = false
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        let description = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.logger.error("Workout session failed: \(description)")
            self?.stopStreaming()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchHeartRateManager: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Not used — we only care about HR samples
    }

    /// Stays on the delegate queue on purpose: the sample is yielded synchronously, in
    /// the order HealthKit produced it. Everything it needs comes from the builder it is
    /// handed, so it touches no main-actor state.
    nonisolated func workoutBuilder(
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
        streamContinuation.withLock { _ = $0?.yield(hr.rounded()) }
    }
}
