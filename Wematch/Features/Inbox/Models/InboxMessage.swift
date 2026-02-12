import Foundation

struct InboxMessage: Identifiable, Sendable {
    let id: String
    let recipientID: String
    let type: InboxMessageType
    let payload: [String: String]
    var isRead: Bool
    let createdAt: Date
}

enum InboxMessageType: String, Sendable {
    case groupJoinRequest
    case groupRequestAccepted
    case groupRequestDeclined
    case groupDeleted
    case friendRequest
    case friendRequestAccepted
    case friendRequestDeclined
    case temporaryRoomInvitation
}

enum InboxAction: Sendable {
    case accept
    case decline
    case join
}
