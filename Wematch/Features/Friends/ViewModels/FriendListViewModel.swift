import Foundation
import OSLog

@Observable
@MainActor
final class FriendListViewModel {

    // MARK: - State

    private(set) var friends: [Friendship] = []
    private(set) var friendProfiles: [String: UserProfile] = [:]
    private(set) var incomingRequests: [FriendRequest] = []
    private(set) var outgoingRequests: [FriendRequest] = []
    private(set) var isLoading = false
    var error: Error?

    var incomingCount: Int { incomingRequests.count }

    // MARK: - Dependencies

    private let repository: any FriendRepository
    private let profileRepository: any UserProfileRepository
    private let inboxRepository: any InboxMessageRepository
    private let authManager: AuthenticationManager

    init(repository: any FriendRepository = CloudKitFriendRepository(),
         profileRepository: any UserProfileRepository = CloudKitUserProfileRepository(),
         inboxRepository: any InboxMessageRepository = CloudKitInboxMessageRepository(),
         authManager: AuthenticationManager) {
        self.repository = repository
        self.profileRepository = profileRepository
        self.inboxRepository = inboxRepository
        self.authManager = authManager
    }

    // MARK: - Computed

    var currentUserID: String? { authManager.currentUserID }

    func friendProfile(for friendship: Friendship) -> UserProfile? {
        guard let userID = currentUserID else { return nil }
        let friendID = friendship.friendID(for: userID)
        return friendProfiles[friendID]
    }

    // MARK: - Fetch

    func fetchAll() async {
        guard let userID = currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedFriends = repository.fetchFriends(userID: userID)
            async let fetchedIncoming = repository.fetchIncomingRequests(userID: userID)
            async let fetchedOutgoing = repository.fetchOutgoingRequests(userID: userID)

            friends = try await fetchedFriends
            incomingRequests = try await fetchedIncoming
            outgoingRequests = try await fetchedOutgoing

            // Fetch profiles for all friends
            for friendship in friends {
                let friendID = friendship.friendID(for: userID)
                if friendProfiles[friendID] == nil {
                    if let profile = try? await profileRepository.fetchProfile(userID: friendID) {
                        friendProfiles[friendID] = profile
                    }
                }
            }
        } catch {
            self.error = error
            Log.friends.error("Failed to fetch friends data: \(error.localizedDescription)")
        }
    }

    // MARK: - Request Actions

    func acceptRequest(_ request: FriendRequest) async {
        do {
            let friendship = try await repository.acceptFriendRequest(request)
            incomingRequests.removeAll { $0.id == request.id }
            friends.append(friendship)

            // Fetch new friend's profile
            if let profile = try? await profileRepository.fetchProfile(userID: request.senderID) {
                friendProfiles[request.senderID] = profile
            }

            // Notify sender
            try? await inboxRepository.createMessage(
                recipientID: request.senderID,
                type: .friendRequestAccepted,
                payload: ["username": authManager.userProfile?.username ?? ""]
            )

            Log.friends.info("Accepted friend request from \(request.senderUsername)")
        } catch {
            self.error = error
            Log.friends.error("Failed to accept request: \(error.localizedDescription)")
        }
    }

    func declineRequest(_ request: FriendRequest) async {
        do {
            try await repository.declineFriendRequest(requestID: request.id)
            incomingRequests.removeAll { $0.id == request.id }

            // Notify sender
            try? await inboxRepository.createMessage(
                recipientID: request.senderID,
                type: .friendRequestDeclined,
                payload: ["username": authManager.userProfile?.username ?? ""]
            )

            Log.friends.info("Declined friend request from \(request.senderUsername)")
        } catch {
            self.error = error
            Log.friends.error("Failed to decline request: \(error.localizedDescription)")
        }
    }

    func cancelRequest(_ request: FriendRequest) async {
        do {
            try await repository.cancelFriendRequest(requestID: request.id)
            outgoingRequests.removeAll { $0.id == request.id }
            Log.friends.info("Canceled friend request to \(request.receiverUsername)")
        } catch {
            self.error = error
            Log.friends.error("Failed to cancel request: \(error.localizedDescription)")
        }
    }

    // MARK: - Friend Actions

    func removeFriend(friendshipID: String) async {
        do {
            try await repository.removeFriend(friendshipID: friendshipID)
            if let removed = friends.first(where: { $0.id == friendshipID }),
               let userID = currentUserID {
                let friendID = removed.friendID(for: userID)
                friendProfiles.removeValue(forKey: friendID)
            }
            friends.removeAll { $0.id == friendshipID }
            Log.friends.info("Removed friendship \(friendshipID)")
        } catch {
            self.error = error
            Log.friends.error("Failed to remove friend: \(error.localizedDescription)")
        }
    }
}
