import Foundation
import WematchCore

/// Building a snapshot is the phone's half of the type.
///
/// `WatchDashboardSnapshot` itself lives in `WematchCore`, because both devices must agree
/// on it exactly. This does not: it reaches into `DashboardRecords`, `DashboardMetrics` and
/// the on-device history, none of which the Watch has or should have (plan 1.11).
extension WatchDashboardSnapshot {

    /// Resolves metrics and records into something the Watch can render directly.
    static func make(
        from records: DashboardRecords,
        userID: String,
        asOf reference: Date = Date()
    ) -> WatchDashboardSnapshot {
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
            starsMade: metrics.totalStars,
            connectedSeconds: metrics.connectedDuration,
            biggestCluster: metrics.maxClusterSize
        )
    }
}
