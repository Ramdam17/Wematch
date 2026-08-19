import Foundation
import OSLog
import WematchCore

/// The phone's ear and mouth on the Watch. Split from `RoomViewModel.swift` to keep
/// that file under the length limit, the same way the dashboard recording is.
extension RoomViewModel {

    /// Consumes the Watch's message stream through the injected protocol — no
    /// singleton, no downcast (plan 1.10).
    ///
    /// Heart rate arrives here too. It used to arrive through
    /// `PhoneSessionManager.shared.heartRateHandler`, a closure installed on the
    /// singleton and pointed at the concrete service the ViewModel obtained by
    /// downcasting its own injected protocol. That is why nothing about the Watch heart
    /// rate path could be tested: the wire went around the seam rather than through it.
    func startObservingWatchMessages() {
        watchMessageTask = Task { [weak self] in
            guard let stream = self?.watchService.messages() else { return }

            for await message in stream {
                guard !Task.isCancelled else { break }
                guard let self else { break }

                switch message {
                case .heartRate(let bpm, _):
                    healthKitService.yield(heartRate: bpm)

                case .heartRateStatus(let status):
                    watchHeartRateStatus = status
                    if status.needsAttention {
                        Log.rooms.error("Watch heart rate unavailable: \(status.rawValue, privacy: .public)")
                    }

                case .appLaunched, .enterRoom, .exitRoom, .roomUpdate, .dashboardUpdate:
                    // Phone → Watch directions. Listed rather than defaulted so that
                    // adding a case to `WatchMessage` fails the build here instead of
                    // being dropped at runtime.
                    continue
                }
            }
        }
    }

    // MARK: - Sending: room state

    /// Push the plot the Watch renders. Internal, not private: it lives here now and
    /// is called from `RoomViewModel`'s sync loop.
    func sendRoomUpdateToWatch(newSyncFormations: Bool) {
        #if !targetEnvironment(simulator)
        let graph = syncGraph
        let maxChain = graph.softClusters.map(\.chainLength).max() ?? 0
        let syncedIDs = Set(graph.softClusters.flatMap(\.memberIDs))

        let participants = allParticipantsForPlot.map { participant in
            WatchMessage.RoomUpdate.Participant(
                id: participant.id,
                currentHR: participant.currentHR,
                previousHR: participant.previousHR,
                colorSlot: participant.slot.index
            )
        }

        // Fire and forget at ~1 Hz, through the protocol rather than the singleton: a
        // dropped frame is replaced a second later, and waiting for an acknowledgement
        // per frame would queue the link behind itself.
        watchService.sendWithoutAcknowledgement(
            .roomUpdate(
                WatchMessage.RoomUpdate(
                    participants: participants,
                    currentUserID: currentUserID ?? "",
                    maxChain: maxChain,
                    syncedCount: syncedIDs.count,
                    newSyncFormations: newSyncFormations
                )
            )
        )
        #endif
    }

    // MARK: - Sending: commands

    func sendWatchCommand(_ message: WatchMessage) {
        Task {
            do {
                try await watchService.send(message)
                isWatchUnreachable = false
                Log.rooms.debug("Sent \(message.logLabel, privacy: .public) to Watch")
            } catch {
                // `send` now throws when the Watch is unreachable instead of returning
                // as if it had sent (plan 1.7, D1) — so this is reachable, and visible.
                Log.rooms.error("Failed to send to Watch: \(error.localizedDescription)")
                isWatchUnreachable = true
            }
        }
    }
}
