import Foundation

struct TemporaryRoom: Identifiable, Sendable {
    let id: String           // "temp_{sortedA}_{sortedB}"
    let friendID: String
    let friendUsername: String
    let createdAt: Date

    /// Generates a deterministic room ID for two users.
    /// Sorted so the same pair always produces the same ID.
    static func roomID(userA: String, userB: String) -> String {
        let sorted = [userA.firebaseSafe(), userB.firebaseSafe()].sorted()
        return "temp_\(sorted[0])_\(sorted[1])"
    }

    /// Extracts the two participant IDs from a temp room ID.
    static func participantIDs(from roomID: String) -> (String, String)? {
        guard roomID.hasPrefix("temp_") else { return nil }
        // Cleanup uses Firebase index data, not ID parsing
        return nil
    }
}
