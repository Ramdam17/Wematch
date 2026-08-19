import Foundation

extension String {
    /// Firebase RTDB keys cannot contain `.` `#` `$` `[` `]`.
    /// Replaces dots with underscores (needed for Apple Sign-In IDs).
    /// `nonisolated`: a pure string transform, called from repositories that are not on
    /// the main actor (plan 1.10).
    nonisolated func firebaseSafe() -> String {
        replacingOccurrences(of: ".", with: "_")
    }
}
