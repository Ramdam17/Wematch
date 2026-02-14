import Foundation

enum GroupError: LocalizedError {
    case groupFull
    case groupNotFound
    case codeNotFound
    case alreadyMember
    case alreadyRequested
    case adminCannotLeave
    case notAdmin
    case emptyName

    var errorDescription: String? {
        switch self {
        case .groupFull: "This group is full (max 20 members)."
        case .groupNotFound: "Group not found."
        case .codeNotFound: "No group found with this code."
        case .alreadyMember: "You are already a member of this group."
        case .alreadyRequested: "You already have a pending request for this group."
        case .adminCannotLeave: "As admin, you must delete the group instead of leaving."
        case .notAdmin: "Only the group admin can perform this action."
        case .emptyName: "Group name cannot be empty."
        }
    }
}

protocol GroupRepository: Sendable {
    // Groups
    func fetchMyGroups(userID: String) async throws -> [Group]
    func createGroup(name: String, adminID: String) async throws -> Group
    func deleteGroup(groupID: String) async throws
    func searchGroups(query: String) async throws -> [Group]
    func fetchGroup(byCode code: String) async throws -> Group?

    // Join requests
    func sendJoinRequest(groupID: String, userID: String, username: String) async throws
    func fetchJoinRequests(groupID: String) async throws -> [JoinRequest]
    func acceptJoinRequest(requestID: String, groupID: String, userID: String) async throws
    func declineJoinRequest(requestID: String) async throws

    // Membership
    func leaveGroup(groupID: String, userID: String) async throws
    func removeMember(groupID: String, userID: String) async throws

    // Account deletion
    func fetchAdminGroups(userID: String) async throws -> [Group]
    func removeUserFromAllGroups(userID: String) async throws
}
