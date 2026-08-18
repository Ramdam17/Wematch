import Foundation

struct InboxMessage: Identifiable, Sendable {
    let id: String
    let recipientID: String
    let type: InboxMessageType
    let payload: [String: String]
    var isRead: Bool
    let createdAt: Date
}

extension InboxMessage {

    /// Decodes one stored document. Pure — takes the raw dictionary rather than a
    /// `DocumentSnapshot` so the mapping is testable without Firestore.
    ///
    /// Fails only on a document with no `type` field at all: that is malformed, and
    /// the app has nothing to show for it. A *known-shaped* document carrying a type
    /// this build has never heard of is NOT a failure — it decodes to
    /// `.unknown` (plan 1.7, audit D3), because a message the server chose to deliver
    /// is a message the user received.
    init?(id: String, recipientID: String, data: [String: Any], createdAt: Date) {
        guard let rawType = data["type"] as? String else { return nil }
        self.init(
            id: id,
            recipientID: recipientID,
            type: InboxMessageType(rawValue: rawType),
            payload: data["payload"] as? [String: String] ?? [:],
            isRead: data["isRead"] as? Bool ?? false,
            createdAt: createdAt
        )
    }
}

/// The kinds of message the inbox carries.
///
/// Not a `String`-backed `RawRepresentable`: `.unknown` has to keep the string the
/// server actually sent, which a compiler-synthesised raw value cannot do. `rawValue`
/// and `init(rawValue:)` are hand-written to the same shape, so call sites read the
/// same — but the init is **not failable**, which is the whole point: there is no
/// longer a way to decode a message into nothing.
enum InboxMessageType: Sendable, Equatable, Hashable {
    case groupJoinRequest
    case groupRequestAccepted
    case groupRequestDeclined
    case groupDeleted
    case friendRequest
    case friendRequestAccepted
    case friendRequestDeclined
    case temporaryRoomInvitation

    /// A type this build does not handle — typically a newer app version writing into
    /// an older one's inbox. Carries the raw string so logs and diagnostics can name it.
    case unknown(String)

    /// Every case this build knows how to render and act on. `.unknown` is excluded
    /// by construction — it is not a type, it is the absence of one.
    static let knownCases: [InboxMessageType] = [
        .groupJoinRequest, .groupRequestAccepted, .groupRequestDeclined, .groupDeleted,
        .friendRequest, .friendRequestAccepted, .friendRequestDeclined, .temporaryRoomInvitation
    ]

    init(rawValue: String) {
        self = Self.knownCases.first { $0.rawValue == rawValue } ?? .unknown(rawValue)
    }

    var rawValue: String {
        switch self {
        case .groupJoinRequest: "groupJoinRequest"
        case .groupRequestAccepted: "groupRequestAccepted"
        case .groupRequestDeclined: "groupRequestDeclined"
        case .groupDeleted: "groupDeleted"
        case .friendRequest: "friendRequest"
        case .friendRequestAccepted: "friendRequestAccepted"
        case .friendRequestDeclined: "friendRequestDeclined"
        case .temporaryRoomInvitation: "temporaryRoomInvitation"
        case .unknown(let raw): raw
        }
    }

    var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

    /// Whether the row offers accept/decline/join. Lives on the type rather than in
    /// the row view so it can be tested, and so `.unknown` is answered in one place:
    /// no button for a message we cannot interpret.
    var hasActions: Bool {
        switch self {
        case .groupJoinRequest, .friendRequest, .temporaryRoomInvitation: true
        default: false
        }
    }
}

enum InboxAction: Sendable {
    case accept
    case decline
    case join
}
