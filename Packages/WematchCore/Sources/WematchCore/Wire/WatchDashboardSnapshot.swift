import Foundation

/// The four numbers the Watch dashboard shows, computed on the iPhone.
///
/// The Watch stays a passive display — it does no aggregation, holds no history, and
/// cannot recompute any of this. Everything it needs to render arrives resolved: the
/// partner already named, the duration already unioned, the cluster already maxed.
///
/// The partner's palette slot travels rather than a colour, for the same reason
/// participants' do (see `HeartPaletteSlot`): each side renders the hue for its own
/// appearance, and a hex on the wire would freeze one.
///
/// Both devices now read this one declaration. Until plan 1.11 there were two, and they
/// had already drifted: only the Watch's had the duration formatting, only the phone's
/// could be built from records.
public struct WatchDashboardSnapshot: Codable, Equatable, Sendable {

    /// The person the user has spent the most time in sync with.
    public var bestPartnerName: String?
    public var bestPartnerSlot: Int?
    /// Sync stars the user has watched appear, across every session.
    public var starsMade: Int
    /// Time connected to at least one other person — the union, not the sum.
    public var connectedSeconds: TimeInterval
    /// Largest cluster the user has been part of, themselves included.
    public var biggestCluster: Int

    public static let empty = WatchDashboardSnapshot(
        bestPartnerName: nil,
        bestPartnerSlot: nil,
        starsMade: 0,
        connectedSeconds: 0,
        biggestCluster: 0
    )

    /// Has the user actually done anything yet?
    public var hasHistory: Bool {
        starsMade > 0 || connectedSeconds > 0 || biggestCluster > 0
    }

    public init(
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

    /// "3h 42m", "42m", "38s" — the coarsest unit that still says something.
    ///
    /// Written out rather than left to a formatter because the Watch renders this at 22pt
    /// in a 348pt-wide row: `DateComponentsFormatter` would happily produce
    /// "3 hours, 42 minutes" and blow the layout apart.
    ///
    /// The phone's dashboard shows the same total, and now calls this rather than
    /// carrying its own copy: the same history formatted two ways reads as two histories.
    /// The table in `DashboardViewModelTests.testTheDurationContractTheWatchIsAlsoWrittenAgainst`
    /// still pins the wording.
    public var connectedDurationText: String {
        let total = Int(connectedSeconds.rounded())
        guard total >= 60 else { return "\(total)s" }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    /// Spoken in full, since "3h 42m" reads as gibberish letter by letter.
    public var connectedDurationSpoken: String {
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
