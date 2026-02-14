import Foundation

/// Aggregated metrics computed from session logs and sync events for dashboard display.
///
/// `DashboardMetrics` is a computed model — it does not persist data itself, but rather
/// summarizes raw `SessionLog` and `SyncEvent` records into human-readable statistics.
/// It is designed to be computed on-demand from the underlying data.
///
/// **Future use:**
/// - Power the Dashboard UI with summary cards
/// - Provide at-a-glance stats (total sessions, total sync time, etc.)
/// - Support time-filtered views (today, this week, all-time)
struct DashboardMetrics: Sendable {
    /// Total number of room sessions the user has participated in.
    let totalSessions: Int

    /// Cumulative time spent in rooms, in seconds.
    let totalSessionDuration: TimeInterval

    /// Average session duration in seconds.
    /// Returns `0` if `totalSessions` is zero.
    let averageSessionDuration: TimeInterval

    /// Total number of sync events the user was involved in.
    let totalSyncEvents: Int

    /// Cumulative time spent in sync with others, in seconds.
    let totalSyncDuration: TimeInterval

    /// The longest single sync event duration, in seconds.
    let longestSyncDuration: TimeInterval

    /// Number of unique users the current user has synced with.
    let uniqueSyncPartners: Int

    /// Computes metrics from raw session logs and sync events.
    ///
    /// - Parameters:
    ///   - sessions: All session logs for the current user.
    ///   - syncEvents: All sync events involving the current user.
    /// - Returns: Aggregated dashboard metrics.
    static func compute(from sessions: [SessionLog], syncEvents: [SyncEvent], userID: String) -> DashboardMetrics {
        let sessionDurations = sessions.map(\.duration)
        let totalDuration = sessionDurations.reduce(0, +)

        let syncDurations = syncEvents.map(\.duration)
        let totalSync = syncDurations.reduce(0, +)

        let partnerIDs = Set(syncEvents.flatMap { $0.userIDs }.filter { $0 != userID })

        return DashboardMetrics(
            totalSessions: sessions.count,
            totalSessionDuration: totalDuration,
            averageSessionDuration: sessions.isEmpty ? 0 : totalDuration / Double(sessions.count),
            totalSyncEvents: syncEvents.count,
            totalSyncDuration: totalSync,
            longestSyncDuration: syncDurations.max() ?? 0,
            uniqueSyncPartners: partnerIDs.count
        )
    }
}
