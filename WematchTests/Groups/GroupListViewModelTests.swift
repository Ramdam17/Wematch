import XCTest
@testable import Wematch

// MARK: - Mock Repository

final class MockGroupRepository: GroupRepository {
    var groups: [Group] = []
    var joinRequests: [JoinRequest] = []
    var deletedGroupIDs: [String] = []
    var leftGroupIDs: [(groupID: String, userID: String)] = []
    var shouldThrowOnLeave = false

    func fetchMyGroups(userID: String) async throws -> [Group] {
        groups.filter { $0.adminID == userID || $0.memberIDs.contains(userID) }
    }

    func createGroup(name: String, adminID: String) async throws -> Group {
        let group = Group(
            id: UUID().uuidString, name: name, code: GroupCodeGenerator.generate(),
            adminID: adminID, memberIDs: [], createdAt: Date()
        )
        groups.append(group)
        return group
    }

    func deleteGroup(groupID: String) async throws {
        deletedGroupIDs.append(groupID)
        groups.removeAll { $0.id == groupID }
    }

    func searchGroups(query: String) async throws -> [Group] {
        groups.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func fetchGroup(byCode code: String) async throws -> Group? {
        groups.first { $0.code == code }
    }

    func sendJoinRequest(groupID: String, userID: String, username: String) async throws {
        joinRequests.append(JoinRequest(
            id: UUID().uuidString, groupID: groupID, userID: userID,
            username: username, status: .pending, createdAt: Date()
        ))
    }

    func fetchJoinRequests(groupID: String) async throws -> [JoinRequest] {
        joinRequests.filter { $0.groupID == groupID && $0.status == .pending }
    }

    func acceptJoinRequest(requestID: String, groupID: String, userID: String) async throws {}
    func declineJoinRequest(requestID: String) async throws {}

    func leaveGroup(groupID: String, userID: String) async throws {
        if shouldThrowOnLeave { throw GroupError.adminCannotLeave }
        leftGroupIDs.append((groupID, userID))
        if let idx = groups.firstIndex(where: { $0.id == groupID }) {
            groups[idx].memberIDs.removeAll { $0 == userID }
        }
    }

    func removeMember(groupID: String, userID: String) async throws {
        if let idx = groups.firstIndex(where: { $0.id == groupID }) {
            groups[idx].memberIDs.removeAll { $0 == userID }
        }
    }
}

// MARK: - Tests

@MainActor
final class GroupListViewModelTests: XCTestCase {

    private var mockRepo: MockGroupRepository!
    private var mockProfileRepo: MockUserProfileRepository!
    private var mockCoordinator: MockSignInWithAppleCoordinator!
    private var authManager: AuthenticationManager!
    private var viewModel: GroupListViewModel!

    override func setUp() {
        super.setUp()
        mockRepo = MockGroupRepository()
        mockProfileRepo = MockUserProfileRepository()
        mockCoordinator = MockSignInWithAppleCoordinator()
        authManager = AuthenticationManager(
            repository: mockProfileRepo,
            coordinator: mockCoordinator
        )
    }

    override func tearDown() {
        try? KeychainService.delete(key: "appleUserID")
        super.tearDown()
    }

    private func signInUser(id: String = "test_user") async {
        try? KeychainService.save(key: "appleUserID", value: id)
        mockProfileRepo.profiles[id] = UserProfile(
            id: id, username: "test_\(id)", displayName: nil,
            createdAt: Date(), usernameEdited: false
        )
        await authManager.restoreSession()
        viewModel = GroupListViewModel(repository: mockRepo, authManager: authManager)
    }

    func testFetchGroupsReturnsUserGroups() async {
        await signInUser()
        mockRepo.groups = [
            Group(id: "g1", name: "Fitness", code: "ABC123",
                  adminID: "test_user", memberIDs: [], createdAt: Date()),
            Group(id: "g2", name: "Family", code: "DEF456",
                  adminID: "other", memberIDs: ["test_user"], createdAt: Date()),
            Group(id: "g3", name: "Secret", code: "GHI789",
                  adminID: "other", memberIDs: [], createdAt: Date())
        ]

        await viewModel.fetchGroups()

        XCTAssertEqual(viewModel.groups.count, 2, "Should only return groups where user is admin or member")
    }

    func testIsAdminCorrectlyIdentifies() async {
        await signInUser()
        let adminGroup = Group(id: "g1", name: "Mine", code: "ABC123",
                               adminID: "test_user", memberIDs: [], createdAt: Date())
        let memberGroup = Group(id: "g2", name: "Theirs", code: "DEF456",
                                adminID: "other", memberIDs: ["test_user"], createdAt: Date())

        XCTAssertTrue(viewModel.isAdmin(adminGroup))
        XCTAssertFalse(viewModel.isAdmin(memberGroup))
    }

    func testDeleteGroupRemovesFromList() async {
        await signInUser()
        mockRepo.groups = [
            Group(id: "g1", name: "Fitness", code: "ABC123",
                  adminID: "test_user", memberIDs: [], createdAt: Date())
        ]
        await viewModel.fetchGroups()
        XCTAssertEqual(viewModel.groups.count, 1)

        await viewModel.deleteGroup(id: "g1")
        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertTrue(mockRepo.deletedGroupIDs.contains("g1"))
    }

    func testLeaveGroupRemovesFromList() async {
        await signInUser()
        mockRepo.groups = [
            Group(id: "g2", name: "Family", code: "DEF456",
                  adminID: "other", memberIDs: ["test_user"], createdAt: Date())
        ]
        await viewModel.fetchGroups()
        XCTAssertEqual(viewModel.groups.count, 1)

        await viewModel.leaveGroup(id: "g2")
        XCTAssertTrue(viewModel.groups.isEmpty)
    }

    func testLeaveGroupAsAdminShowsError() async {
        await signInUser()
        mockRepo.shouldThrowOnLeave = true
        mockRepo.groups = [
            Group(id: "g1", name: "Mine", code: "ABC123",
                  adminID: "test_user", memberIDs: [], createdAt: Date())
        ]
        await viewModel.fetchGroups()

        await viewModel.leaveGroup(id: "g1")
        XCTAssertNotNil(viewModel.error, "Should set error when admin tries to leave")
    }
}
