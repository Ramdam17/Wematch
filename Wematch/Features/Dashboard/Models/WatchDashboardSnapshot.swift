import Foundation

/// The four numbers the Watch dashboard shows, computed on the iPhone.
///
/// The Watch stays a passive display — it does no aggregation, holds no history, and
/// cannot recompute any of this. Everything it needs to render arrives resolved: the
/// partner already named, the duration already unioned, the cluster already maxed.
///
/// The partner's palette slot travels rather than a colour, for the same reason
/// participants' do (see `HeartPaletteSlot`): each side renders the hue for its own mode,
/// and a hex on the wire would freeze one.
struct WatchDashboardSnapshot: Codable, Sendable, Equatable {

    /// The person the user has spent the most time in sync with.
    var bestPartnerName: String?
    var bestPartnerSlot: Int?

    /// Sync stars the user has watched appear, across every session.
    var starsMade: Int

    /// Time connected to at least one other person — the union, not the sum.
    var connectedSeconds: TimeInterval

    /// Largest cluster the user has been part of, themselves included.
    var biggestCluster: Int

    static let empty = WatchDashboardSnapshot(
        bestPartnerName: nil,
        bestPartnerSlot: nil,
        starsMade: 0,
        connectedSeconds: 0,
        biggestCluster: 0
    )

    /// Resolves metrics and records into something the Watch can render directly.
    static func make(from records: DashboardRecords, userID: String, asOf reference: Date = Date()) -> WatchDashboardSnapshot {
        let metrics = DashboardMetrics.compute(
            from: records.sessions,
            syncEvents: records.syncEvents,
            userID: userID,
            asOf: reference
        )

        let partnerID = metrics.bestPartner?.userID

        return WatchDashboardSnapshot(
            bestPartnerName: partnerID.flatMap { records.displayNames[$0] },
            bestPartnerSlot: partnerID.map { HeartPaletteSlot(userID: $0).index },
            // Stars are counted per session as they appear on screen, not derived from
            // the sync events — see `SessionLog.starsSpawned`.
            starsMade: records.sessions.reduce(0) { $0 + $1.starsSpawned },
            connectedSeconds: metrics.connectedDuration,
            biggestCluster: metrics.maxClusterSize
        )
    }

    // MARK: - Wire format

    /// WCSession carries property-list types, not `Codable`, so the snapshot crosses as a
    /// plain dictionary. Kept next to the type rather than at the call site so both sides
    /// read the same key names.
    var messagePayload: [String: Any] {
        var payload: [String: Any] = [
            "starsMade": starsMade,
            "connectedSeconds": connectedSeconds,
            "biggestCluster": biggestCluster
        ]
        if let bestPartnerName { payload["bestPartnerName"] = bestPartnerName }
        if let bestPartnerSlot { payload["bestPartnerSlot"] = bestPartnerSlot }
        return payload
    }
}
