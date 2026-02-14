import Foundation

/// A record of a synchronization event between two or more users in a room.
///
/// A `SyncEvent` is created when hearts come within the sync threshold (< 5 BPM
/// Euclidean distance in 2D) and ends when they drift apart. These events capture
/// the "magic moments" of the app — when users' heart rates align.
///
/// **Future use:**
/// - Display sync timeline in Dashboard
/// - Calculate total sync duration with each friend
/// - Track longest sync streak (consecutive syncs in a session)
/// - Show "most synced with" leaderboard
/// - Compute sync frequency trends over time
struct SyncEvent: Identifiable, Codable, Sendable {
    /// Unique identifier for this sync event.
    let id: String

    /// The ID of the room where the sync occurred.
    let roomID: String

    /// The IDs of all users involved in this sync event.
    /// Always contains at least 2 user IDs.
    let userIDs: [String]

    /// The timestamp when the sync was first detected.
    let startedAt: Date

    /// The timestamp when the sync ended (hearts drifted apart).
    /// `nil` if the sync is still active.
    var endedAt: Date?

    /// The duration of the sync event in seconds.
    /// Returns `0` if the sync is still active.
    var duration: TimeInterval {
        guard let endedAt else { return 0 }
        return endedAt.timeIntervalSince(startedAt)
    }
}
