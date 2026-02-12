import Foundation
import OSLog

enum UserFriendStatus {
    case canAdd
    case pending
    case alreadyFriends
}

@Observable
@MainActor
final class UserSearchViewModel {

    // MARK: - State

    var searchText = ""
    private(set) var results: [UserProfile] = []
    private(set) var sentRequestUserIDs: Set<String> = []
    private(set) var isSearching = false
    var error: Error?

    // Pre-loaded context
    private var existingFriendIDs: Set<String> = []
    private var pendingRequestUserIDs: Set<String> = []

    // MARK: - Dependencies

    private let repository: any FriendRepository
    private let inboxRepository: any InboxMessageRepository
    private let authManager: AuthenticationManager

    init(repository: any FriendRepository = CloudKitFriendRepository(),
         inboxRepository: any InboxMessageRepository = CloudKitInboxMessageRepository(),
         authManager: AuthenticationManager) {
        self.repository = repository
        self.inboxRepository = inboxRepository
        self.authManager = authManager
    }

    // MARK: - Setup

    func loadContext() async {
        guard let userID = authManager.currentUserID else { return }

        do {
            let friendships = try await repository.fetchFriends(userID: userID)
            existingFriendIDs = Set(friendships.map { $0.friendID(for: userID) })

            let outgoing = try await repository.fetchOutgoingRequests(userID: userID)
            pendingRequestUserIDs = Set(outgoing.map(\.receiverID))

            let incoming = try await repository.fetchIncomingRequests(userID: userID)
            pendingRequestUserIDs.formUnion(incoming.map(\.senderID))
        } catch {
            Log.friends.error("Failed to load search context: \(error.localizedDescription)")
        }
    }

    // MARK: - Search

    func search() async {
        guard let userID = authManager.currentUserID else { return }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await repository.searchUsers(query: query, excludingUserID: userID)
        } catch {
            self.error = error
            Log.friends.error("Search failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Status

    func status(for userID: String) -> UserFriendStatus {
        if existingFriendIDs.contains(userID) { return .alreadyFriends }
        if pendingRequestUserIDs.contains(userID) || sentRequestUserIDs.contains(userID) { return .pending }
        return .canAdd
    }

    // MARK: - Send Request

    func sendRequest(to user: UserProfile) async {
        guard let senderID = authManager.currentUserID,
              let senderUsername = authManager.userProfile?.username else { return }

        do {
            try await repository.sendFriendRequest(
                senderID: senderID,
                receiverID: user.id,
                senderUsername: senderUsername,
                receiverUsername: user.username
            )
            sentRequestUserIDs.insert(user.id)

            // Notify receiver
            try? await inboxRepository.createMessage(
                recipientID: user.id,
                type: .friendRequest,
                payload: ["senderUsername": senderUsername, "senderID": senderID]
            )

            Log.friends.info("Sent friend request to \(user.username)")
        } catch {
            self.error = error
            Log.friends.error("Failed to send request: \(error.localizedDescription)")
        }
    }
}
