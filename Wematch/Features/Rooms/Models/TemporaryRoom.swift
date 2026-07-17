import Foundation

struct TemporaryRoom: Identifiable, Sendable {
    let id: String           // "temp_{sortedA}_{sortedB}"
    let friendID: String
    let friendUsername: String
    let createdAt: Date

    /// Generates a deterministic room ID for two users (Firebase UIDs).
    /// Sorted so the same pair always produces the same ID. The ID is an
    /// opaque key — participant IDs are stored in room metadata, never
    /// parsed back out of this string (audit E1).
    static func roomID(userA: String, userB: String) -> String {
        let sorted = [userA.firebaseSafe(), userB.firebaseSafe()].sorted()
        return "temp_\(sorted[0])_\(sorted[1])"
    }
}
