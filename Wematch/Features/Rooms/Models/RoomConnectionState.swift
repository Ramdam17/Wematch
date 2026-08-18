import Foundation

/// The one thing the room tells the user about its own health (plan 1.7, audit D1–D3).
///
/// Three links can break independently — the Firebase stream that shows the others, the
/// Watch that produces our heart, and the write that publishes it — and until now all
/// three failed into the same picture: a plot that looks like a quiet room. They are
/// folded into a single state, worst first, so there is exactly one place to look and
/// one thing for VoiceOver to read.
///
/// Ordering is by *how much of what is on screen is false*:
/// `offline` (no network, everything else follows) > `roomUnreachable` (everything shown
/// is stale) > `watchUnreachable` (no heart at all,
/// and it names the cause) > `heartRateUnavailable` (no heart, cause unknown) >
/// `notSharing` (we see them, they do not see us).
enum RoomConnectionState: Equatable, Hashable, Sendable {

    /// Every link that should be up is up.
    case connected

    /// The device is not reaching the database at all. Distinct from `roomUnreachable`
    /// because the two are observed by different mechanisms and neither sees the other:
    /// losing the network does not *cancel* a Realtime Database listener, it merely
    /// stops feeding it, so only `.info/connected` reports it.
    case offline

    /// The participants stream died — typically a permission error or a lost network.
    /// Whatever hearts are on the plot are frozen in the past.
    case roomUnreachable

    /// The phone could not reach the Watch app at all, so the room never asked it for a
    /// heart rate. **This path has no automated test**: the Watch commands are compiled
    /// out of simulator builds, so it is covered by case S8 of
    /// `Docs/field-tests/session-script.md` and nothing else.
    case watchUnreachable

    /// The Watch is there and says its own heart-rate feed is dead. Carries the Watch's
    /// verdict rather than re-deciding it here.
    case heartRateUnavailable(WatchHeartRateStatus)

    /// Our heart rate is arriving but failing to publish: the room shows us a stale or
    /// missing heart to everyone else.
    case notSharing

    /// Folds the independent facts into the one state shown. Pure — this is where the
    /// precedence lives, and the only thing the tests need to pin down.
    static func resolve(isOffline: Bool,
                        roomUnreachable: Bool,
                        watchUnreachable: Bool,
                        watchHeartRate: WatchHeartRateStatus,
                        isSharingHeartRate: Bool) -> RoomConnectionState {
        // Ordered by cause before consequence: with no network every other link is
        // down too, and "you're offline" is the only one the user can act on.
        if isOffline { return .offline }
        if roomUnreachable { return .roomUnreachable }
        if watchUnreachable { return .watchUnreachable }
        if watchHeartRate.needsAttention { return .heartRateUnavailable(watchHeartRate) }
        if !isSharingHeartRate { return .notSharing }
        return .connected
    }

    /// True when the user should be told something instead of being left to read an
    /// empty plot as a quiet room.
    var needsAttention: Bool { self != .connected }

    /// Reserved for the state where what is already on screen is *wrong* rather than
    /// merely incomplete — the only one that earns the loud tint.
    var isCritical: Bool { self == .roomUnreachable || self == .offline }

    /// One sentence, naming the fact and, where there is one, the fix.
    var message: String? {
        switch self {
        case .connected:
            nil
        case .offline:
            "You're offline. The hearts here have stopped updating."
        case .roomUnreachable:
            "The room isn't answering. What you see here has stopped updating."
        case .watchUnreachable:
            "Can't reach your Watch. Open Wematch on it to share your heart."
        case .heartRateUnavailable(let status):
            // The phone's wording, not the Watch's: same fact, one line. The Watch keeps
            // the actionable instruction, because it is the device that can act on it.
            status.phoneSummary
        case .notSharing:
            "Your heart isn't reaching the room."
        }
    }
}
