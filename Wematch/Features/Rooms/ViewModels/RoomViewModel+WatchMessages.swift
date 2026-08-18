import Foundation
import OSLog

/// The phone's ear and mouth on the Watch. Split from `RoomViewModel.swift` to keep
/// that file under the length limit, the same way the dashboard recording is.
extension RoomViewModel {

    /// Consumes the Watch's message stream through the injected protocol — no
    /// singleton, no downcast. `receivedMessages` already existed on
    /// `WatchConnectivityServiceProtocol` and nothing read it, which is why the
    /// Watch could report a dead heart-rate feed that the phone never heard.
    func startObservingWatchMessages() {
        watchMessageTask = Task { [weak self] in
            guard let stream = self?.watchService.receivedMessages else { return }

            for await message in stream {
                guard !Task.isCancelled else { break }
                guard let type = message["type"] as? String, type == "heartRateStatus" else {
                    continue
                }
                guard let raw = message["status"] as? String,
                      let status = WatchHeartRateStatus(rawValue: raw) else {
                    Log.watchConnectivity.error("Unrecognised heart rate status payload")
                    continue
                }
                self?.watchHeartRateStatus = status
                if status.needsAttention {
                    Log.rooms.error("Watch heart rate unavailable: \(status.rawValue, privacy: .public)")
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

        let participantDicts: [[String: Any]] = allParticipantsForPlot.map { p in
            [
                "id": p.id,
                "currentHR": p.currentHR,
                "previousHR": p.previousHR,
                "colorSlot": p.slot.index
            ]
        }

        PhoneSessionManager.shared.sendRoomUpdate(
            participants: participantDicts,
            currentUserID: currentUserID ?? "",
            maxChain: maxChain,
            syncedCount: syncedIDs.count,
            newSyncFormations: newSyncFormations
        )
        #endif
    }

    // MARK: - Sending: commands

    func sendWatchCommand(_ type: String, roomID: String? = nil) {
        var message: [String: Any] = ["type": type]
        if let roomID { message["roomID"] = roomID }

        Task {
            do {
                try await watchService.send(message: message)
                isWatchUnreachable = false
                Log.rooms.debug("Sent \(type) command to Watch")
            } catch {
                // `send` now throws when the Watch is unreachable instead of returning
                // as if it had sent (plan 1.7, D1) — so this is reachable, and visible.
                Log.rooms.error("Failed to send \(type) to Watch: \(error.localizedDescription)")
                isWatchUnreachable = true
            }
        }
    }
}
