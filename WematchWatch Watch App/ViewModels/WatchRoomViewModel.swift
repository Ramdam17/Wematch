import Foundation
import os

@Observable
@MainActor
final class WatchRoomViewModel {

    private let logger = Logger(
        subsystem: "com.remyramadour.Wematch.watchkitapp",
        category: "room"
    )

    // MARK: - Published State

    private(set) var participants: [WatchParticipant] = []
    private(set) var currentUserID: String = ""
    private(set) var ownHeartRate: Double = 0
    private(set) var maxChain: Int = 0
    private(set) var syncedCount: Int = 0
    private(set) var isInRoom = false
    private(set) var isStreaming = false

    /// Whether heart rate is actually arriving. `isStreaming` only says a workout
    /// was started; it stays true while a denied read produces nothing forever.
    private(set) var heartRateStatus: WatchHeartRateStatus = .idle

    // MARK: - Dependencies

    private let heartRateManager: WatchHeartRateManager

    // MARK: - Tasks

    private var streamTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?

    // MARK: - Init

    init(heartRateManager: WatchHeartRateManager) {
        self.heartRateManager = heartRateManager
    }

    // MARK: - Room Lifecycle

    func enterRoom() {
        guard !isInRoom else { return }
        isInRoom = true

        // Wire up room update handler
        WatchSessionManager.shared.roomUpdateHandler = { [weak self] update in
            self?.handleRoomUpdate(update)
        }

        // Start HR streaming
        streamTask = Task {
            if !heartRateManager.hasRequestedAuthorization {
                do {
                    try await heartRateManager.requestAuthorization()
                } catch {
                    logger.error("HealthKit auth request failed: \(error.localizedDescription)")
                    isInRoom = false
                    update(.stopped)
                    return
                }
            }

            isStreaming = true
            update(.waitingForFirstSample)
            startSilenceWatchdog()

            for await hr in heartRateManager.startStreaming() {
                guard !Task.isCancelled else { break }
                ownHeartRate = hr
                update(.streaming)
                WatchSessionManager.shared.sendHeartRate(hr)
            }

            isStreaming = false
            silenceTask?.cancel()
            silenceTask = nil

            // The stream ended. If it never produced a sample, say so instead of
            // leaving a plot that is empty for an unexplained reason.
            if !Task.isCancelled, heartRateStatus != .streaming {
                update(.stopped)
            }
        }

        logger.info("Watch room entered")
    }

    func exitRoom() {
        streamTask?.cancel()
        streamTask = nil
        silenceTask?.cancel()
        silenceTask = nil
        heartRateManager.stopStreaming()
        WatchSessionManager.shared.roomUpdateHandler = nil

        isInRoom = false
        isStreaming = false
        update(.idle)
        ownHeartRate = 0
        participants = []
        maxChain = 0
        syncedCount = 0

        logger.info("Watch room exited")
    }

    // MARK: - Heart Rate Status

    /// Records the status, logs it, and tells the iPhone. Every transition goes
    /// through here so that no state change is observable on one device only.
    private func update(_ status: WatchHeartRateStatus) {
        guard heartRateStatus != status else { return }
        heartRateStatus = status
        logger.info("Heart rate status: \(status.rawValue, privacy: .public)")
        WatchSessionManager.shared.sendHeartRateStatus(status)
    }

    /// Flips to `.silent` if the first sample never arrives. This is the whole
    /// point: a denied heart-rate read is invisible through HealthKit, so absence
    /// over time is the only evidence available.
    private func startSilenceWatchdog() {
        silenceTask?.cancel()
        silenceTask = Task {
            try? await Task.sleep(for: WatchHeartRateStatus.firstSampleTimeout)
            guard !Task.isCancelled, heartRateStatus == .waitingForFirstSample else { return }
            update(.silent)
        }
    }

    // MARK: - Room Update Handler

    private func handleRoomUpdate(_ update: WatchRoomUpdate) {
        participants = update.participants
        currentUserID = update.currentUserID
        maxChain = update.maxChain
        syncedCount = update.syncedCount

        if update.newSyncFormations {
            WatchHapticService.triggerSyncFormation()
        }
    }
}
