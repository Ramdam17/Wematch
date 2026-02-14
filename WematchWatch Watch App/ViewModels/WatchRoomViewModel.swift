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

    // MARK: - Dependencies

    private let heartRateManager: WatchHeartRateManager

    // MARK: - Tasks

    private var streamTask: Task<Void, Never>?

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
            if !heartRateManager.isAuthorized {
                do {
                    try await heartRateManager.requestAuthorization()
                } catch {
                    logger.error("HealthKit auth failed: \(error.localizedDescription)")
                    isInRoom = false
                    return
                }
            }

            isStreaming = true

            for await hr in heartRateManager.startStreaming() {
                guard !Task.isCancelled else { break }
                ownHeartRate = hr
                WatchSessionManager.shared.sendHeartRate(hr)
            }

            isStreaming = false
        }

        logger.info("Watch room entered")
    }

    func exitRoom() {
        streamTask?.cancel()
        streamTask = nil
        heartRateManager.stopStreaming()
        WatchSessionManager.shared.roomUpdateHandler = nil

        isInRoom = false
        isStreaming = false
        ownHeartRate = 0
        participants = []
        maxChain = 0
        syncedCount = 0

        logger.info("Watch room exited")
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
