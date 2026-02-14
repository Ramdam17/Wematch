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
        let parts = roomID.replacingOccurrences(of: "temp_", with: "")
        // The ID format is "{sortedA}_{sortedB}" where each part may contain underscores
        // Since we sorted them, we split into exactly 2 parts by finding the midpoint
        // However, user IDs from Apple Sign-In are like "001234_5678" (dots replaced with _)
        // We stored the full safe IDs in the Firebase index, so this helper is secondary.
        // For cleanup we rely on the Firebase index, not ID parsing.
        guard roomID.hasPrefix("temp_") else { return nil }
        return nil // Cleanup uses Firebase index data, not ID parsing
    }
}
