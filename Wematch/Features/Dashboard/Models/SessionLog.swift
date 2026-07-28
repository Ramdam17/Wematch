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
struct SessionLog: Identifiable, Codable, Equatable, Sendable {
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

    /// How many sync stars appeared during this session.
    ///
    /// Counted here rather than derived from `SyncEvent`, because the two answer
    /// different questions. A star marks one new *pair* coming into sync; a `SyncEvent`
    /// covers a whole cluster over a stretch of time. Deriving "stars made" from the
    /// event count would report the number of times the cluster changed shape, which is
    /// not what the user watched happen on screen.
    var starsSpawned: Int = 0

    /// The duration of the session in seconds.
    /// Computed from `joinedAt` and `leftAt`. Returns `0` if the session is still active.
    var duration: TimeInterval {
        guard let leftAt else { return 0 }
        return leftAt.timeIntervalSince(joinedAt)
    }

    // A record written before `starsSpawned` existed decodes as zero rather than
    // failing, so one added field cannot cost the user their whole history.
    private enum CodingKeys: String, CodingKey {
        case id, roomID, userID, joinedAt, leftAt, starsSpawned
    }

    init(
        id: String,
        roomID: String,
        userID: String,
        joinedAt: Date,
        leftAt: Date? = nil,
        starsSpawned: Int = 0
    ) {
        self.id = id
        self.roomID = roomID
        self.userID = userID
        self.joinedAt = joinedAt
        self.leftAt = leftAt
        self.starsSpawned = starsSpawned
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        roomID = try container.decode(String.self, forKey: .roomID)
        userID = try container.decode(String.self, forKey: .userID)
        joinedAt = try container.decode(Date.self, forKey: .joinedAt)
        leftAt = try container.decodeIfPresent(Date.self, forKey: .leftAt)
        starsSpawned = try container.decodeIfPresent(Int.self, forKey: .starsSpawned) ?? 0
    }
}
