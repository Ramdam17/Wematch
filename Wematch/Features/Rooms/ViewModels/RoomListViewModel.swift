import Foundation
import OSLog

@Observable
@MainActor
final class RoomListViewModel {

    // MARK: - State

    private(set) var groups: [Group] = []
    private(set) var isLoading = false
    var error: Error?

    // MARK: - Dependencies

    private let groupRepository: any GroupRepository
    private let authManager: AuthenticationManager

    // MARK: - Init

    init(groupRepository: (any GroupRepository)? = nil,
         authManager: AuthenticationManager) {
        self.groupRepository = groupRepository ?? CloudKitGroupRepository()
        self.authManager = authManager
    }

    // MARK: - Computed

    var currentUserID: String? { authManager.currentUserID }

    // MARK: - Actions

    func fetchGroups() async {
        guard let userID = currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            groups = try await groupRepository.fetchMyGroups(userID: userID)
            Log.rooms.debug("Fetched \(self.groups.count) groups as available rooms")
        } catch {
            self.error = error
            Log.rooms.error("Failed to fetch groups for rooms: \(error.localizedDescription)")
        }
    }
}
