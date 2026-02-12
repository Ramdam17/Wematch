import Foundation

enum JoinRequestStatus: String, Sendable {
    case pending
    case accepted
    case declined
}

struct JoinRequest: Identifiable, Sendable {
    let id: String
    let groupID: String
    let userID: String
    let username: String
    var status: JoinRequestStatus
    let createdAt: Date
}
