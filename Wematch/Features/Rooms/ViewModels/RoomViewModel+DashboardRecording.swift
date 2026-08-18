import Foundation
import OSLog

/// Everything the room does *for the dashboard*, kept out of `RoomViewModel` proper.
///
/// Recording is a genuinely separate job from running a room: nothing on the plot, the
/// HUD or the Firebase sync depends on any of it, and a failure here must never affect
/// the session. Splitting it also keeps `RoomViewModel` under the file-length limit
/// rather than widening the limit for it.
///
/// `recorder` and `dashboardStore` are internal rather than private for this reason — an
/// extension in another file cannot see private members.
extension RoomViewModel {

    /// Opens a recording session.
    ///
    /// - Parameter userID: the raw user ID; it is keyed on its firebaseSafe form here,
    ///   because that is what the sync graph's cluster members are keyed on. Mixing the
    ///   two forms would make the user their own sync partner.
    func startDashboardRecording(userID: String, at instant: Date = Date()) {
        recorder = SyncSessionRecorder(
            roomID: roomID,
            userID: userID.firebaseSafe(),
            startedAt: instant
        )
    }

    /// Feeds the recorder what just happened on the plot.
    ///
    /// - Parameter starsSpawned: how many stars actually appeared, which is the count
    ///   after the hard cap rather than the number of new pairs — the dashboard reports
    ///   what the user watched happen, not what would have happened uncapped.
    func recordDashboardState(starsSpawned: Int, at instant: Date = Date()) {
        guard var recorder, let userID = currentUserID else { return }

        let safeUserID = userID.firebaseSafe()

        // The user's connected component: everyone they are transitively in sync with.
        // They belong to at most one, since components partition the graph.
        let cluster = syncGraph.softClusters
            .first { $0.memberIDs.contains(safeUserID) }
            .map { Set($0.memberIDs) } ?? []

        recorder.observe(cluster: cluster, at: instant)
        recorder.recordStars(starsSpawned)
        recorder.noteDisplayNames(
            Dictionary(
                allParticipantsForPlot.map { ($0.id, $0.username) },
                uniquingKeysWith: { _, new in new }
            )
        )

        self.recorder = recorder
    }

    /// Closes the session, writes it, and refreshes the Watch.
    ///
    /// Runs even when the session is already gone (sign-out mid-room): what happened in
    /// the room happened, and the records never leave the device anyway.
    func flushDashboardRecords(at instant: Date = Date()) async {
        guard var recorder else { return }
        self.recorder = nil

        let records = recorder.finish(at: instant)

        do {
            try dashboardStore.append(records)
            Log.rooms.info(
                "Recorded session: \(records.syncEvents.count) sync events, \(records.sessions.first?.starsSpawned ?? 0) stars"
            )
        } catch {
            // Best effort on the way out, but never silent — a dashboard that quietly
            // stops growing is indistinguishable from one nobody uses.
            Log.rooms.error("Failed to persist dashboard records: \(error.localizedDescription)")
        }

        await pushDashboardSnapshotToWatch()
    }

    /// Sends the Watch a resolved dashboard snapshot.
    ///
    /// Goes through `watchService` rather than `PhoneSessionManager.shared`: the protocol
    /// already carries arbitrary messages, so there is no reason to add a call site to the
    /// singleton (plan 1.10 is removing the ones that exist).
    func pushDashboardSnapshotToWatch() async {
        guard let userID = currentUserID else { return }

        let store = dashboardStore
        let safeUserID = userID.firebaseSafe()

        do {
            // Off the main actor: the file grows with every session the user ever plays,
            // and a glanceable screen is not worth a hitch on the plot.
            let records = try await Task.detached { try store.load() }.value
            let snapshot = WatchDashboardSnapshot.make(from: records, userID: safeUserID)

            var message = snapshot.messagePayload
            message["type"] = "dashboardUpdate"
            try await watchService.send(message: message)
        } catch {
            // The Watch simply keeps the numbers it had; nothing on the phone depends on
            // this landing, but a silent failure would make a stale Watch inexplicable.
            Log.rooms.warning("Failed to push dashboard snapshot to Watch: \(error.localizedDescription)")
        }
    }
}
