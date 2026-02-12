import Foundation

enum FriendRequestStatus: String, Sendable {
    case pending
    case accepted
    case declined
}

struct FriendRequest: Identifiable, Sendable {
    let id: String
    let senderID: String
    let receiverID: String
    let senderUsername: String
    let receiverUsername: String
    var status: FriendRequestStatus
    let createdAt: Date
}
