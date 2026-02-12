import Foundation
import OSLog

@Observable
@MainActor
final class GroupListViewModel {

    // MARK: - State

    private(set) var groups: [Group] = []
    private(set) var isLoading = false
    var error: Error?

    // MARK: - Dependencies

    private let repository: any GroupRepository
    private let authManager: AuthenticationManager

    init(repository: any GroupRepository = CloudKitGroupRepository(),
         authManager: AuthenticationManager) {
        self.repository = repository
        self.authManager = authManager
    }

    // MARK: - Computed

    var currentUserID: String? { authManager.currentUserID }

    func isAdmin(_ group: Group) -> Bool {
        group.adminID == authManager.currentUserID
    }

    // MARK: - Actions

    func fetchGroups() async {
        guard let userID = authManager.currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            groups = try await repository.fetchMyGroups(userID: userID)
        } catch {
            self.error = error
            Log.groups.error("Failed to fetch groups: \(error.localizedDescription)")
        }
    }

    func deleteGroup(id: String) async {
        do {
            try await repository.deleteGroup(groupID: id)
            groups.removeAll { $0.id == id }
            Log.groups.info("Deleted group \(id)")
        } catch {
            self.error = error
            Log.groups.error("Failed to delete group: \(error.localizedDescription)")
        }
    }

    func leaveGroup(id: String) async {
        guard let userID = authManager.currentUserID else { return }

        do {
            try await repository.leaveGroup(groupID: id, userID: userID)
            groups.removeAll { $0.id == id }
            Log.groups.info("Left group \(id)")
        } catch {
            self.error = error
            Log.groups.error("Failed to leave group: \(error.localizedDescription)")
        }
    }
}
