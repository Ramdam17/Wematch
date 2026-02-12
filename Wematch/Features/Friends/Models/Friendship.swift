import Foundation

struct Friendship: Identifiable, Sendable {
    let id: String
    let userID1: String
    let userID2: String
    let createdAt: Date

    func friendID(for currentUserID: String) -> String {
        currentUserID == userID1 ? userID2 : userID1
    }
}
