import Foundation

/// Turns a live room session into the records the dashboard is computed from.
///
/// One recorder per session. It watches the user's sync cluster — everyone they are
/// transitively in sync with — and whenever that set changes it closes the open
/// `SyncEvent` and opens the next one. Consecutive events therefore *touch*, which is
/// deliberate: a cluster gaining a member is not a break in being connected, and
/// `DashboardMetrics.connectedDuration` merges touching intervals into one stretch.
///
/// A pure value type with no clock and no storage of its own, so the whole recording
/// contract is testable by calling `observe(cluster:at:)` with dates.
struct SyncSessionRecorder {

    private(set) var session: SessionLog
    private(set) var completedEvents: [SyncEvent] = []
    private(set) var displayNames: [String: String] = [:]

    private var openEvent: SyncEvent?
    private var currentCluster: Set<String> = []

    private let userID: String
    private let makeEventID: () -> String

    init(
        sessionID: String = UUID().uuidString,
        roomID: String,
        userID: String,
        startedAt: Date,
        makeEventID: @escaping () -> String = { UUID().uuidString }
    ) {
        self.userID = userID
        self.makeEventID = makeEventID
        self.session = SessionLog(
            id: sessionID,
            roomID: roomID,
            userID: userID,
            joinedAt: startedAt
        )
    }

    /// Records the user's current sync cluster.
    ///
    /// - Parameters:
    ///   - members: every ID in the user's connected component, the user included. Fewer
    ///     than two means they are synced with nobody, which closes any open event.
    ///   - instant: when this state was observed.
    mutating func observe(cluster members: Set<String>, at instant: Date) {
        let cluster = members.count >= 2 ? members : []
        guard cluster != currentCluster else { return }

        closeOpenEvent(at: instant)

        if !cluster.isEmpty {
            openEvent = SyncEvent(
                id: makeEventID(),
                roomID: session.roomID,
                userIDs: cluster.sorted(),
                startedAt: instant,
                endedAt: nil
            )
        }

        currentCluster = cluster
    }

    /// Counts stars the room just spawned. One star is one new pair coming into sync.
    mutating func recordStars(_ count: Int) {
        guard count > 0 else { return }
        session.starsSpawned += count
    }

    /// Remembers the names of people seen in the room, so the dashboard can name a
    /// partner later without a lookup.
    mutating func noteDisplayNames(_ names: [String: String]) {
        for (id, name) in names where id != userID && !name.isEmpty {
            displayNames[id] = name
        }
    }

    /// Closes the session and any event still open, and hands back everything recorded.
    mutating func finish(at instant: Date) -> DashboardRecords {
        closeOpenEvent(at: instant)
        currentCluster = []
        session.leftAt = instant

        return DashboardRecords(
            sessions: [session],
            syncEvents: completedEvents,
            displayNames: displayNames
        )
    }

    // MARK: - Private

    private mutating func closeOpenEvent(at instant: Date) {
        guard var event = openEvent else { return }
        openEvent = nil

        // A cluster that formed and dissolved inside one observation carries no time and
        // would only dilute the averages.
        guard instant > event.startedAt else { return }

        event.endedAt = instant
        completedEvents.append(event)
    }
}
