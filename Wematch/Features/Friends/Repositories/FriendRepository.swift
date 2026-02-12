import Foundation

protocol FriendRepository: Sendable {
    func fetchFriends() async throws -> [UserProfile]
    func sendFriendRequest(to userID: String) async throws
    func acceptFriendRequest(requestID: String) async throws
    func declineFriendRequest(requestID: String) async throws
    func removeFriend(userID: String) async throws
    func searchUsers(query: String) async throws -> [UserProfile]
}
