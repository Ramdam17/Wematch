import Foundation

enum FriendError: LocalizedError {
    case alreadyFriends
    case alreadyRequested
    case selfRequest
    case requestNotFound

    var errorDescription: String? {
        switch self {
        case .alreadyFriends: "You are already friends."
        case .alreadyRequested: "A friend request is already pending."
        case .selfRequest: "You cannot send a friend request to yourself."
        case .requestNotFound: "Friend request not found."
        }
    }
}

protocol FriendRepository: Sendable {
    // Friends
    func fetchFriends(userID: String) async throws -> [Friendship]
    func removeFriend(friendshipID: String) async throws

    // Requests
    func sendFriendRequest(senderID: String, receiverID: String,
                           senderUsername: String, receiverUsername: String) async throws
    func fetchIncomingRequests(userID: String) async throws -> [FriendRequest]
    func fetchOutgoingRequests(userID: String) async throws -> [FriendRequest]
    func acceptFriendRequest(_ request: FriendRequest) async throws -> Friendship
    func declineFriendRequest(requestID: String) async throws
    func cancelFriendRequest(requestID: String) async throws

    // Search
    func searchUsers(query: String, excludingUserID: String) async throws -> [UserProfile]

    // Account deletion
    func deleteAllFriendData(userID: String) async throws
}
