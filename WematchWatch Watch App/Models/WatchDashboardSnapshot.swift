import Foundation

/// The Watch's copy of the dashboard numbers.
///
/// Duplicated from the iPhone target rather than shared, like every other model here:
/// `WematchShared` is iOS-only. The keys must match `WatchDashboardSnapshot`'s
/// `messagePayload` on the phone side — keep the two in sync by hand.
///
/// Nothing is computed here. The Watch is a passive display: the phone unioned the
/// intervals, picked the partner and resolved their name before any of it crossed.
struct WatchDashboardSnapshot: Equatable, Sendable {

    var bestPartnerName: String?
    var bestPartnerSlot: Int?
    var starsMade: Int
    var connectedSeconds: TimeInterval
    var biggestCluster: Int

    static let empty = WatchDashboardSnapshot(
        bestPartnerName: nil,
        bestPartnerSlot: nil,
        starsMade: 0,
        connectedSeconds: 0,
        biggestCluster: 0
    )

    /// Has the user actually done anything yet?
    var hasHistory: Bool {
        starsMade > 0 || connectedSeconds > 0 || biggestCluster > 0
    }

    init(
        bestPartnerName: String?,
        bestPartnerSlot: Int?,
        starsMade: Int,
        connectedSeconds: TimeInterval,
        biggestCluster: Int
    ) {
        self.bestPartnerName = bestPartnerName
        self.bestPartnerSlot = bestPartnerSlot
        self.starsMade = starsMade
        self.connectedSeconds = connectedSeconds
        self.biggestCluster = biggestCluster
    }

    /// Decodes a WCSession payload, tolerating anything missing — a partial message
    /// should degrade to zeros, never drop the whole update.
    init?(message: [String: Any]) {
        guard message["type"] as? String == "dashboardUpdate" else { return nil }

        self.bestPartnerName = message["bestPartnerName"] as? String
        self.bestPartnerSlot = message["bestPartnerSlot"] as? Int
        self.starsMade = message["starsMade"] as? Int ?? 0
        self.connectedSeconds = message["connectedSeconds"] as? TimeInterval ?? 0
        self.biggestCluster = message["biggestCluster"] as? Int ?? 0
    }

    /// "3h 42m", "42m", "38s" — the coarsest unit that still says something.
    ///
    /// Written out rather than left to a formatter because the Watch renders this at 22pt
    /// in a 348pt-wide row: `DateComponentsFormatter` would happily produce
    /// "3 hours, 42 minutes" and blow the layout apart.
    ///
    /// Must match `DashboardViewModel.durationText` on the phone — the same history shown
    /// two ways reads as two histories. Neither target can import the other, so the
    /// contract is the table in
    /// `DashboardViewModelTests.testTheDurationContractTheWatchIsAlsoWrittenAgainst`;
    /// change both together.
    var connectedDurationText: String {
        let total = Int(connectedSeconds.rounded())
        guard total >= 60 else { return "\(total)s" }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    /// Spoken in full, since "3h 42m" reads as gibberish letter by letter.
    var connectedDurationSpoken: String {
        let total = Int(connectedSeconds.rounded())
        guard total >= 60 else { return "\(total) seconds" }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }
}
