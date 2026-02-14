import Foundation

extension String {
    /// Firebase RTDB keys cannot contain `.` `#` `$` `[` `]`.
    /// Replaces dots with underscores (needed for Apple Sign-In IDs).
    func firebaseSafe() -> String {
        replacingOccurrences(of: ".", with: "_")
    }
}
