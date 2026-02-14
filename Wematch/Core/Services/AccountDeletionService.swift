import Foundation
import OSLog

final class AccountDeletionService: Sendable {

    private let groupRepository: any GroupRepository
    private let friendRepository: any FriendRepository
    private let inboxRepository: any InboxRepository
    private let inboxMessageRepository: any InboxMessageRepository
    private let profileRepository: any UserProfileRepository
    private let tempRoomRepository: any TemporaryRoomRepository

    init(
        groupRepository: (any GroupRepository)? = nil,
        friendRepository: (any FriendRepository)? = nil,
        inboxRepository: (any InboxRepository)? = nil,
        inboxMessageRepository: (any InboxMessageRepository)? = nil,
        profileRepository: (any UserProfileRepository)? = nil,
        tempRoomRepository: (any TemporaryRoomRepository)? = nil
    ) {
        self.groupRepository = groupRepository ?? CloudKitGroupRepository()
        self.friendRepository = friendRepository ?? CloudKitFriendRepository()
        self.inboxRepository = inboxRepository ?? CloudKitInboxRepository()
        self.inboxMessageRepository = inboxMessageRepository ?? CloudKitInboxMessageRepository()
        self.profileRepository = profileRepository ?? CloudKitUserProfileRepository()
        self.tempRoomRepository = tempRoomRepository ?? FirebaseTemporaryRoomRepository()
    }

    func deleteAllData(userID: String) async throws {
        Log.settings.info("Starting account deletion for user \(userID)")

        // 1. Delete admin groups (notify members first)
        try await deleteAdminGroups(userID: userID)

        // 2. Remove user from all groups they're a member of
        try await groupRepository.removeUserFromAllGroups(userID: userID)

        // 3. Delete all friend data
        try await friendRepository.deleteAllFriendData(userID: userID)

        // 4. Delete all inbox messages
        try await inboxRepository.deleteAllMessages(userID: userID)

        // 5. Clean up temp room Firebase indexes
        try await deleteTempRooms(userID: userID)

        // 6. Delete user profile from CloudKit
        try await profileRepository.deleteProfile(userID: userID)

        Log.settings.info("Account deletion complete for user \(userID)")
    }

    // MARK: - Private

    private func deleteAdminGroups(userID: String) async throws {
        let adminGroups = try await groupRepository.fetchAdminGroups(userID: userID)

        for group in adminGroups {
            // Notify all members that the group is being deleted
            for memberID in group.memberIDs {
                try? await inboxMessageRepository.createMessage(
                    recipientID: memberID,
                    type: .groupDeleted,
                    payload: ["groupName": group.name]
                )
            }

            // Delete the group (and its join requests)
            try await groupRepository.deleteGroup(groupID: group.id)
        }

        if !adminGroups.isEmpty {
            Log.settings.info("Deleted \(adminGroups.count) admin groups and notified members")
        }
    }

    private func deleteTempRooms(userID: String) async throws {
        let tempRooms = try await tempRoomRepository.fetchActiveRooms(userID: userID)

        for room in tempRooms {
            // Delete the room index entries and Firebase data
            try? await tempRoomRepository.deleteRoom(
                roomID: room.id,
                userA: userID.firebaseSafe(),
                userB: room.friendID
            )
        }

        if !tempRooms.isEmpty {
            Log.settings.info("Cleaned up \(tempRooms.count) temp rooms")
        }
    }
}
