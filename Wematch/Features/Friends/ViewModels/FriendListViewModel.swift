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

    /// Set after creating a temp room — triggers navigation in FriendListView.
    var pendingRoomNavigation: (roomID: String, roomName: String)?

    var incomingCount: Int { incomingRequests.count }

    // MARK: - Dependencies

    private let repository: any FriendRepository
    private let profileRepository: any UserProfileRepository
    private let inboxRepository: any InboxMessageRepository
    private let tempRoomRepository: any TemporaryRoomRepository
    private let authManager: AuthenticationManager

    init(repository: (any FriendRepository)? = nil,
         profileRepository: (any UserProfileRepository)? = nil,
         inboxRepository: (any InboxMessageRepository)? = nil,
         tempRoomRepository: (any TemporaryRoomRepository)? = nil,
         authManager: AuthenticationManager) {
        self.repository = repository ?? CloudKitFriendRepository()
        self.profileRepository = profileRepository ?? CloudKitUserProfileRepository()
        self.inboxRepository = inboxRepository ?? CloudKitInboxMessageRepository()
        self.tempRoomRepository = tempRoomRepository ?? FirebaseTemporaryRoomRepository()
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

    // MARK: - Temporary Room

    func startRoom(with friendProfile: UserProfile) async {
        guard let userID = currentUserID,
              let username = authManager.userProfile?.username else { return }

        let roomID = TemporaryRoom.roomID(userA: userID, userB: friendProfile.id)

        do {
            // Create temp room index entries for both users
            try await tempRoomRepository.createRoom(
                roomID: roomID,
                userA: userID,
                userB: friendProfile.id,
                userAUsername: username,
                userBUsername: friendProfile.username
            )

            // Send inbox invitation to friend
            try await inboxRepository.createMessage(
                recipientID: friendProfile.id,
                type: .temporaryRoomInvitation,
                payload: [
                    "roomID": roomID,
                    "senderID": userID,
                    "senderUsername": username
                ]
            )

            // Trigger navigation
            pendingRoomNavigation = (roomID, "Room with \(friendProfile.username)")

            Log.friends.info("Started temp room \(roomID) with \(friendProfile.username)")
        } catch {
            self.error = error
            Log.friends.error("Failed to start room: \(error.localizedDescription)")
        }
    }
}
