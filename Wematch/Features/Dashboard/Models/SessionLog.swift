import Foundation

/// A log entry representing a user's participation in a room session.
///
/// Each time a user joins and leaves a room, a `SessionLog` is created to record
/// the time window and duration. These logs will be used in the Dashboard to display
/// session history, total time spent, and activity trends over time.
///
/// **Future use:**
/// - Populate "Session History" list in Dashboard
/// - Compute total time spent in rooms (daily, weekly, all-time)
/// - Calculate average session duration
/// - Identify most active time-of-day patterns
struct SessionLog: Identifiable, Codable, Sendable {
    /// Unique identifier for this session log entry.
    let id: String

    /// The ID of the room the user participated in.
    /// Maps to either a group room or a temporary room.
    let roomID: String

    /// The ID of the user who participated in the session.
    let userID: String

    /// The timestamp when the user joined the room.
    let joinedAt: Date

    /// The timestamp when the user left the room.
    /// `nil` if the session is still active.
    var leftAt: Date?

    /// The duration of the session in seconds.
    /// Computed from `joinedAt` and `leftAt`. Returns `0` if the session is still active.
    var duration: TimeInterval {
        guard let leftAt else { return 0 }
        return leftAt.timeIntervalSince(joinedAt)
    }
}
