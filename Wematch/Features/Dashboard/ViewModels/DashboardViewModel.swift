import Foundation
import OSLog

@Observable
@MainActor
final class DashboardViewModel {

    enum State: Equatable {
        case loading
        /// The flag is off; the screen should not have been reachable.
        case unavailable
        /// Nothing recorded yet — the user has never been in sync with anyone.
        case empty
        case loaded(DashboardMetrics)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.unavailable, .unavailable), (.empty, .empty):
                true
            case let (.loaded(a), .loaded(b)):
                a.connectedDuration == b.connectedDuration && a.totalSessions == b.totalSessions
            default:
                false
            }
        }
    }

    private(set) var state: State = .loading
    private(set) var bestPartnerName: String?
    private(set) var bestPartnerSlot: HeartPaletteSlot?
    var error: Error?

    private let store: any DashboardRecordStoring
    private let authManager: AuthenticationManager
    private let featureFlags: any FeatureFlagProvider

    init(
        authManager: AuthenticationManager,
        store: (any DashboardRecordStoring)? = nil,
        featureFlags: any FeatureFlagProvider
    ) {
        self.authManager = authManager
        self.store = store ?? DashboardRecordStore()
        self.featureFlags = featureFlags
    }

    func load() async {
        // Checked here rather than in the view, so the rule holds even if another entry
        // point to this screen appears.
        guard featureFlags.isEnabled(.dashboardAccess) else {
            state = .unavailable
            return
        }

        guard let userID = authManager.currentUserID else {
            state = .empty
            return
        }

        let store = self.store
        let safeUserID = userID.firebaseSafe()

        do {
            // Off the main actor: the file carries every session the user has ever played.
            let records = try await Task.detached { try store.load() }.value

            guard !records.isEmpty else {
                state = .empty
                return
            }

            let metrics = DashboardMetrics.compute(
                from: records.sessions,
                syncEvents: records.syncEvents,
                userID: safeUserID
            )

            bestPartnerName = metrics.bestPartner.flatMap { records.displayNames[$0.userID] }
            bestPartnerSlot = metrics.bestPartner.map { HeartPaletteSlot(userID: $0.userID) }
            state = .loaded(metrics)
        } catch {
            // Surfaced, not swallowed: an unreadable history is a real failure and the
            // difference between "you have done nothing" and "we cannot read it" matters.
            self.error = error
            state = .empty
            Log.settings.error("Failed to load dashboard records: \(error.localizedDescription)")
        }
    }

    // MARK: - Formatting

    /// "3h 42m", "42m", "38s" — the coarsest unit that still says something.
    ///
    /// Mirrors `WatchDashboardSnapshot.connectedDurationText` so the two screens never
    /// disagree about the same number.
    nonisolated static func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        guard total >= 60 else { return "\(total)s" }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    /// Spoken in full: "3h 42m" reads as gibberish letter by letter.
    nonisolated static func durationSpoken(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        guard total >= 60 else { return "\(total) seconds" }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }
}
