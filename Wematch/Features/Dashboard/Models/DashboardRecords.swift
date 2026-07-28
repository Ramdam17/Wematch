import Foundation

/// Everything the dashboard is computed from, as one persistable unit.
///
/// Kept on device only. These records describe who the user synced with and for how
/// long — personal data about other people as much as about them — so they never leave
/// the phone and `AccountDeletionService` erases them along with everything else.
struct DashboardRecords: Codable, Sendable, Equatable {

    var sessions: [SessionLog]
    var syncEvents: [SyncEvent]

    /// Local `userID → username` cache.
    ///
    /// The metrics identify the best partner by ID, but the Watch has to show a name, and
    /// by then that person may be in none of the user's rooms. Resolving through the
    /// friend graph would put a network call behind a glanceable screen; remembering the
    /// name the user already saw does not. A stale name is the cost, and it is corrected
    /// the next time the two share a room.
    var displayNames: [String: String]

    static let empty = DashboardRecords(sessions: [], syncEvents: [], displayNames: [:])

    init(
        sessions: [SessionLog] = [],
        syncEvents: [SyncEvent] = [],
        displayNames: [String: String] = [:]
    ) {
        self.sessions = sessions
        self.syncEvents = syncEvents
        self.displayNames = displayNames
    }

    /// Folds another batch in. Later names win, so a rename propagates.
    mutating func merge(_ other: DashboardRecords) {
        sessions.append(contentsOf: other.sessions)
        syncEvents.append(contentsOf: other.syncEvents)
        displayNames.merge(other.displayNames) { _, new in new }
    }

    var isEmpty: Bool {
        sessions.isEmpty && syncEvents.isEmpty
    }
}
