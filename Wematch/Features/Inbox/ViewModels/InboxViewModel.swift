import Foundation
import OSLog

@Observable
@MainActor
final class InboxViewModel {

    // MARK: - State

    private(set) var messages: [InboxMessage] = []
    private(set) var isLoading = false
    var error: Error?

    var unreadCount: Int {
        messages.filter { !$0.isRead }.count
    }

    // MARK: - Dependencies

    private let inboxRepository: any InboxRepository
    private let groupRepository: any GroupRepository
    private let friendRepository: any FriendRepository
    private let authManager: AuthenticationManager

    init(inboxRepository: (any InboxRepository)? = nil,
         groupRepository: (any GroupRepository)? = nil,
         friendRepository: (any FriendRepository)? = nil,
         authManager: AuthenticationManager) {
        self.inboxRepository = inboxRepository ?? CloudKitInboxRepository()
        self.groupRepository = groupRepository ?? CloudKitGroupRepository()
        self.friendRepository = friendRepository ?? CloudKitFriendRepository()
        self.authManager = authManager
    }

    // MARK: - Fetch

    func fetchMessages() async {
        guard let userID = authManager.currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await inboxRepository.fetchMessages(userID: userID)
            Log.inbox.debug("Loaded \(self.messages.count) inbox messages")
        } catch {
            self.error = error
            Log.inbox.error("Failed to fetch inbox: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    func performAction(_ action: InboxAction, on message: InboxMessage) async {
        do {
            switch message.type {
            case .groupJoinRequest:
                try await handleGroupJoinRequest(action: action, message: message)
            case .friendRequest:
                try await handleFriendRequest(action: action, message: message)
            default:
                break
            }

            // Remove message from list after action
            try? await inboxRepository.deleteMessage(messageID: message.id)
            messages.removeAll { $0.id == message.id }
        } catch {
            self.error = error
            Log.inbox.error("Failed to perform action on message \(message.id): \(error.localizedDescription)")
        }
    }

    func deleteMessage(_ message: InboxMessage) async {
        do {
            try await inboxRepository.deleteMessage(messageID: message.id)
            messages.removeAll { $0.id == message.id }
            Log.inbox.info("Deleted message \(message.id)")
        } catch {
            self.error = error
            Log.inbox.error("Failed to delete message: \(error.localizedDescription)")
        }
    }

    func markAllAsRead() async {
        guard let userID = authManager.currentUserID else { return }

        do {
            try await inboxRepository.markAllAsRead(userID: userID)
            for index in messages.indices {
                messages[index].isRead = true
            }
            Log.inbox.info("Marked all messages as read")
        } catch {
            self.error = error
            Log.inbox.error("Failed to mark all as read: \(error.localizedDescription)")
        }
    }

    func refreshUnreadCount() async -> Int {
        guard let userID = authManager.currentUserID else { return 0 }
        do {
            return try await inboxRepository.unreadCount(userID: userID)
        } catch {
            Log.inbox.error("Failed to fetch unread count: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Private Handlers

    private func handleGroupJoinRequest(action: InboxAction, message: InboxMessage) async throws {
        guard let requestID = message.payload["requestID"],
              let groupID = message.payload["groupID"],
              let userID = message.payload["userID"] else {
            Log.inbox.warning("Missing payload for groupJoinRequest action")
            return
        }

        switch action {
        case .accept:
            try await groupRepository.acceptJoinRequest(
                requestID: requestID, groupID: groupID, userID: userID
            )
            Log.inbox.info("Accepted group join request \(requestID) from inbox")
        case .decline:
            try await groupRepository.declineJoinRequest(requestID: requestID)
            Log.inbox.info("Declined group join request \(requestID) from inbox")
        case .join:
            break
        }
    }

    private func handleFriendRequest(action: InboxAction, message: InboxMessage) async throws {
        guard let requestID = message.payload["requestID"],
              let senderID = message.payload["senderID"],
              let senderUsername = message.payload["senderUsername"] else {
            Log.inbox.warning("Missing payload for friendRequest action")
            return
        }

        let receiverID = authManager.currentUserID ?? ""
        let receiverUsername = authManager.userProfile?.username ?? ""

        switch action {
        case .accept:
            let request = FriendRequest(
                id: requestID,
                senderID: senderID,
                receiverID: receiverID,
                senderUsername: senderUsername,
                receiverUsername: receiverUsername,
                status: .pending,
                createdAt: Date()
            )
            _ = try await friendRepository.acceptFriendRequest(request)
            Log.inbox.info("Accepted friend request \(requestID) from inbox")
        case .decline:
            try await friendRepository.declineFriendRequest(requestID: requestID)
            Log.inbox.info("Declined friend request \(requestID) from inbox")
        case .join:
            break
        }
    }
}
