import Foundation

/// What the Watch actually knows about its own heart-rate feed.
///
/// HealthKit never reports a denied *read*. `requestAuthorization` returns
/// normally whether the user tapped Allow or Don't Allow, and a denied type then
/// behaves exactly like a type with no data: "To prevent possible information
/// leaks, an app isn't aware when the user denies permission to read data. From
/// the app's point of view, no data of that type exists." (Apple, *Protecting
/// User Privacy*.) A denial, a sensor that has not locked on, and a failed
/// workout session are therefore indistinguishable through the API.
///
/// Silence is the only thing observable, so the app names it instead of
/// rendering an empty plot that looks like a working room.
///
/// Duplicated in the iPhone target until `WematchShared` becomes a real package
/// (plan 1.11) — same pattern as `WatchDashboardSnapshot`.
enum WatchHeartRateStatus: String, Equatable, Sendable, CaseIterable {

    /// No room, no workout — nothing is expected.
    case idle

    /// The workout started; the first sample has not arrived yet, and it is
    /// still early enough that this is normal.
    case waitingForFirstSample

    /// Samples are arriving.
    case streaming

    /// The workout is running and nothing has arrived within `firstSampleTimeout`.
    /// Most likely a denied heart-rate read, possibly a sensor that never locked on.
    case silent

    /// The stream ended without ever delivering a sample — a workout session that
    /// failed to start, or one torn down before the sensor produced anything.
    case stopped

    /// How long to wait for the first sample before saying so.
    ///
    /// **Unmeasured.** No Wematch build has ever run on a real Watch, so this is a
    /// starting point, not a result. `HKLiveWorkoutBuilder` delivers heart rate in
    /// bursts of a few seconds once the sensor has locked on, and the cold start
    /// right after `beginCollection` is the slow case. Case S2 of
    /// `Docs/field-tests/session-script.md` is where this number gets replaced by
    /// a measurement.
    static let firstSampleTimeout: Duration = .seconds(20)

    /// True when the user should be told something, rather than left looking at
    /// a plot that is empty for reasons the app is hiding.
    var needsAttention: Bool {
        self == .silent || self == .stopped
    }

    /// Shown on the Watch and logged on the phone. Written to be actionable:
    /// it names the most likely cause and where to fix it.
    var explanation: String? {
        switch self {
        case .idle, .waitingForFirstSample, .streaming:
            nil
        case .silent:
            "No heart rate yet. Check Wematch has heart-rate access in the Watch Settings app."
        case .stopped:
            "The workout stopped before any heart rate arrived."
        }
    }
}
