import Foundation
import OSLog

@Observable
@MainActor
final class CreateGroupViewModel {

    // MARK: - State

    var name: String = ""
    private(set) var isLoading = false
    private(set) var createdGroup: Group?
    var error: Error?

    // MARK: - Dependencies

    private let repository: any GroupRepository
    private let authManager: AuthenticationManager

    init(repository: any GroupRepository = CloudKitGroupRepository(),
         authManager: AuthenticationManager) {
        self.repository = repository
        self.authManager = authManager
    }

    // MARK: - Actions

    func createGroup() async {
        guard let userID = authManager.currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let group = try await repository.createGroup(name: name, adminID: userID)
            createdGroup = group
            Log.groups.info("Created group '\(group.name)' with code \(group.code)")
        } catch {
            self.error = error
            Log.groups.error("Failed to create group: \(error.localizedDescription)")
        }
    }
}
