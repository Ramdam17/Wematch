import Foundation
import OSLog

@Observable
@MainActor
final class GroupDetailViewModel {

    // MARK: - State

    private(set) var group: Group
    private(set) var joinRequests: [JoinRequest] = []
    private(set) var memberProfiles: [UserProfile] = []
    private(set) var isLoading = false
    private(set) var isDeleted = false
    private(set) var hasLeft = false
    var error: Error?

    var isAdmin: Bool { group.adminID == authManager.currentUserID }
    var memberCount: Int { group.memberIDs.count + 1 } // +1 for admin

    // MARK: - Dependencies

    private let repository: any GroupRepository
    private let profileRepository: any UserProfileRepository
    private let inboxRepository: any InboxMessageRepository
    private let authManager: AuthenticationManager

    init(group: Group,
         repository: any GroupRepository = CloudKitGroupRepository(),
         profileRepository: any UserProfileRepository = CloudKitUserProfileRepository(),
         inboxRepository: any InboxMessageRepository = CloudKitInboxMessageRepository(),
         authManager: AuthenticationManager) {
        self.group = group
        self.repository = repository
        self.profileRepository = profileRepository
        self.inboxRepository = inboxRepository
        self.authManager = authManager
    }

    // MARK: - Fetch

    func fetchDetails() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch join requests (admin only)
            if isAdmin {
                joinRequests = try await repository.fetchJoinRequests(groupID: group.id)
            }

            // Fetch member profiles (admin + all members)
            var profiles: [UserProfile] = []
            let allUserIDs = [group.adminID] + group.memberIDs
            for userID in allUserIDs {
                if let profile = try await profileRepository.fetchProfile(userID: userID) {
                    profiles.append(profile)
                }
            }
            memberProfiles = profiles
        } catch {
            self.error = error
            Log.groups.error("Failed to fetch group details: \(error.localizedDescription)")
        }
    }

    // MARK: - Join Requests

    func acceptRequest(_ request: JoinRequest) async {
        do {
            try await repository.acceptJoinRequest(
                requestID: request.id, groupID: group.id, userID: request.userID
            )
            joinRequests.removeAll { $0.id == request.id }
            group.memberIDs.append(request.userID)

            // Notify the requester
            try? await inboxRepository.createMessage(
                recipientID: request.userID,
                type: .groupRequestAccepted,
                payload: ["groupName": group.name, "groupID": group.id]
            )

            // Refresh member profiles
            if let profile = try? await profileRepository.fetchProfile(userID: request.userID) {
                memberProfiles.append(profile)
            }

            Log.groups.info("Accepted request from \(request.username) for group \(self.group.name)")
        } catch {
            self.error = error
            Log.groups.error("Failed to accept request: \(error.localizedDescription)")
        }
    }

    func declineRequest(_ request: JoinRequest) async {
        do {
            try await repository.declineJoinRequest(requestID: request.id)
            joinRequests.removeAll { $0.id == request.id }

            // Notify the requester
            try? await inboxRepository.createMessage(
                recipientID: request.userID,
                type: .groupRequestDeclined,
                payload: ["groupName": group.name]
            )

            Log.groups.info("Declined request from \(request.username)")
        } catch {
            self.error = error
            Log.groups.error("Failed to decline request: \(error.localizedDescription)")
        }
    }

    // MARK: - Membership

    func removeMember(userID: String) async {
        do {
            try await repository.removeMember(groupID: group.id, userID: userID)
            group.memberIDs.removeAll { $0 == userID }
            memberProfiles.removeAll { $0.id == userID }
            Log.groups.info("Removed member \(userID) from group \(self.group.name)")
        } catch {
            self.error = error
            Log.groups.error("Failed to remove member: \(error.localizedDescription)")
        }
    }

    func leaveGroup() async {
        guard let userID = authManager.currentUserID else { return }

        do {
            try await repository.leaveGroup(groupID: group.id, userID: userID)
            hasLeft = true
            Log.groups.info("Left group \(self.group.name)")
        } catch {
            self.error = error
            Log.groups.error("Failed to leave group: \(error.localizedDescription)")
        }
    }

    func deleteGroup() async {
        do {
            // Notify all members before deleting
            for memberID in group.memberIDs {
                try? await inboxRepository.createMessage(
                    recipientID: memberID,
                    type: .groupDeleted,
                    payload: ["groupName": group.name]
                )
            }

            try await repository.deleteGroup(groupID: group.id)
            isDeleted = true
            Log.groups.info("Deleted group \(self.group.name)")
        } catch {
            self.error = error
            Log.groups.error("Failed to delete group: \(error.localizedDescription)")
        }
    }
}
