import Foundation

/// How long the user was in sync with one particular person.
struct SyncPartnerTotal: Equatable, Sendable {
    let userID: String
    let duration: TimeInterval
}

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
    ///
    /// This is the Watch dashboard's "Stars made": the iPhone spawns one star per new
    /// sync formation, so an event and a star are the same occurrence counted once.
    let totalSyncEvents: Int

    /// Cumulative time spent in sync with others, in seconds — the plain **sum** of every
    /// event's duration.
    ///
    /// Deliberately kept alongside `connectedDuration` rather than replaced by it. This
    /// one answers "how much syncing happened", counting a minute spent synced with three
    /// people as three minutes. That is the right number for a per-relationship total and
    /// the wrong one for "how long was I connected" — see `connectedDuration`.
    let totalSyncDuration: TimeInterval

    /// Time spent connected to **at least one** other person, in seconds — the *union* of
    /// the sync intervals.
    ///
    /// The Watch's "Time in sync". A minute inside a five-way cluster is one minute of
    /// being connected, but ten pairwise events; summing them reports ten. Only the union
    /// can be compared against `totalSessionDuration` without exceeding it.
    let connectedDuration: TimeInterval

    /// The longest single sync event duration, in seconds.
    let longestSyncDuration: TimeInterval

    /// Number of unique users the current user has synced with.
    let uniqueSyncPartners: Int

    /// The person the user has spent the most time in sync with, if there is one.
    let bestPartner: SyncPartnerTotal?

    /// Sync stars the user has actually watched appear.
    ///
    /// Summed from the sessions, **not** derived from `totalSyncEvents`. A star marks one
    /// new pair coming into sync; an event covers a whole cluster over a stretch of time.
    /// Counting events would report how often the cluster changed shape, which is not what
    /// anyone saw happen.
    let totalStars: Int

    /// The largest number of people simultaneously in one sync cluster with the user.
    ///
    /// The Watch's "Biggest cluster". Counts the whole cluster, the user included, which
    /// is why the design renders it as "x5" rather than "5 friends".
    let maxClusterSize: Int

    /// Computes metrics from raw session logs and sync events.
    ///
    /// - Parameters:
    ///   - sessions: All session logs for the current user.
    ///   - syncEvents: All sync events involving the current user.
    ///   - userID: The current user, excluded from partner tallies.
    ///   - reference: The instant an ongoing sync is measured up to. Injected rather than
    ///     read from the clock so the results are reproducible in tests.
    /// - Returns: Aggregated dashboard metrics.
    static func compute(
        from sessions: [SessionLog],
        syncEvents: [SyncEvent],
        userID: String,
        asOf reference: Date = Date()
    ) -> DashboardMetrics {
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
            // Qualified: each of these shares its name with a stored property above.
            connectedDuration: Self.connectedDuration(from: syncEvents, asOf: reference),
            longestSyncDuration: syncDurations.max() ?? 0,
            uniqueSyncPartners: partnerIDs.count,
            bestPartner: Self.bestPartner(from: syncEvents, userID: userID, asOf: reference),
            totalStars: sessions.reduce(0) { $0 + $1.starsSpawned },
            maxClusterSize: Self.maxClusterSize(from: syncEvents)
        )
    }

    // MARK: - Derived metrics

    /// Total length of the union of every sync interval.
    ///
    /// Sweep-line merge over intervals sorted by start: overlapping or touching stretches
    /// extend the one in hand, a gap closes it and opens the next.
    static func connectedDuration(
        from syncEvents: [SyncEvent],
        asOf reference: Date = Date()
    ) -> TimeInterval {
        merge(intervals(of: syncEvents, asOf: reference))
    }

    /// The partner with the most time in sync with the user.
    ///
    /// Each partner's total is itself a union, for the same reason the overall figure is:
    /// two overlapping cluster events that both include the same person are one stretch
    /// of being with them.
    ///
    /// Ties break on the user ID so the dashboard names the same person every time rather
    /// than flickering between equals.
    static func bestPartner(
        from syncEvents: [SyncEvent],
        userID: String,
        asOf reference: Date = Date()
    ) -> SyncPartnerTotal? {
        var eventsByPartner: [String: [SyncEvent]] = [:]

        for event in syncEvents {
            for partnerID in Set(event.userIDs) where partnerID != userID {
                eventsByPartner[partnerID, default: []].append(event)
            }
        }

        let totals = eventsByPartner.map { partnerID, events in
            SyncPartnerTotal(
                userID: partnerID,
                duration: merge(intervals(of: events, asOf: reference))
            )
        }

        return totals.max { lhs, rhs in
            lhs.duration == rhs.duration
                ? lhs.userID > rhs.userID
                : lhs.duration < rhs.duration
        }
    }

    /// The largest cluster the user was part of.
    ///
    /// De-duplicates each event's IDs: a malformed record listing someone twice would
    /// otherwise inflate the headline number.
    static func maxClusterSize(from syncEvents: [SyncEvent]) -> Int {
        syncEvents.map { Set($0.userIDs).count }.max() ?? 0
    }

    // MARK: - Interval arithmetic

    private static func intervals(of syncEvents: [SyncEvent], asOf reference: Date) -> [Range<Date>] {
        syncEvents.compactMap { event in
            // An ongoing sync runs to `reference`. `SyncEvent.duration` reports 0 for one,
            // which is right for a record of a completed event and wrong here: the
            // dashboard would stall for as long as the user stayed in sync.
            let end = event.endedAt ?? reference
            guard end > event.startedAt else { return nil }
            return event.startedAt..<end
        }
    }

    private static func merge(_ intervals: [Range<Date>]) -> TimeInterval {
        let sorted = intervals.sorted { $0.lowerBound < $1.lowerBound }
        guard var current = sorted.first else { return 0 }

        var total: TimeInterval = 0

        for interval in sorted.dropFirst() {
            if interval.lowerBound <= current.upperBound {
                current = current.lowerBound..<max(current.upperBound, interval.upperBound)
            } else {
                total += current.upperBound.timeIntervalSince(current.lowerBound)
                current = interval
            }
        }

        return total + current.upperBound.timeIntervalSince(current.lowerBound)
    }
}
