import Foundation
import os
import WematchCore

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
    private var roomUpdateTask: Task<Void, Never>?

    // MARK: - Init

    init(heartRateManager: WatchHeartRateManager) {
        self.heartRateManager = heartRateManager
    }

    // MARK: - Room Lifecycle

    func enterRoom() {
        guard !isInRoom else { return }
        isInRoom = true

        // Take our own stream of what the iPhone sends. It used to be a closure stored
        // on the session manager: a `var` written here on the main actor, read on the
        // WatchConnectivity delegate queue, and re-dispatched through
        // `DispatchQueue.main.async` — a data race wrapped in an ordering hazard
        // (plan 1.10).
        roomUpdateTask = Task { [weak self] in
            for await message in WatchSessionManager.shared.messages() {
                guard case .roomUpdate(let update) = message else { continue }
                self?.handleRoomUpdate(update)
            }
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
                WatchSessionManager.shared.send(.heartRate(bpm: hr, at: Date()))
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
        roomUpdateTask?.cancel()
        roomUpdateTask = nil

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
        WatchSessionManager.shared.send(.heartRateStatus(status))
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

    private func handleRoomUpdate(_ update: WatchMessage.RoomUpdate) {
        participants = update.participants.map(WatchParticipant.init)
        currentUserID = update.currentUserID
        maxChain = update.maxChain
        syncedCount = update.syncedCount

        if update.newSyncFormations {
            WatchHapticService.triggerSyncFormation()
        }
    }
}
