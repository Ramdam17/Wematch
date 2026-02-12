import XCTest
@testable import Wematch

// MARK: - Mock Inbox Repository

final class MockInboxRepository: InboxRepository {
    var messages: [InboxMessage] = []
    var markedAsReadIDs: [String] = []
    var markedAllAsReadUserIDs: [String] = []
    var deletedMessageIDs: [String] = []

    func fetchMessages(userID: String) async throws -> [InboxMessage] {
        messages.filter { $0.recipientID == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func markAsRead(messageID: String) async throws {
        markedAsReadIDs.append(messageID)
        if let idx = messages.firstIndex(where: { $0.id == messageID }) {
            messages[idx].isRead = true
        }
    }

    func markAllAsRead(userID: String) async throws {
        markedAllAsReadUserIDs.append(userID)
        for idx in messages.indices where messages[idx].recipientID == userID {
            messages[idx].isRead = true
        }
    }

    func deleteMessage(messageID: String) async throws {
        deletedMessageIDs.append(messageID)
        messages.removeAll { $0.id == messageID }
    }

    func unreadCount(userID: String) async throws -> Int {
        messages.filter { $0.recipientID == userID && !$0.isRead }.count
    }
}

// MARK: - Mock Group Repository (for inbox actions)

final class MockInboxGroupRepository: GroupRepository {
    var acceptedRequests: [(requestID: String, groupID: String, userID: String)] = []
    var declinedRequestIDs: [String] = []

    func fetchMyGroups(userID: String) async throws -> [Group] { [] }
    func createGroup(name: String, adminID: String) async throws -> Group {
        Group(id: UUID().uuidString, name: name, code: "ABC123",
              adminID: adminID, memberIDs: [], createdAt: Date())
    }
    func deleteGroup(groupID: String) async throws {}
    func searchGroups(query: String) async throws -> [Group] { [] }
    func fetchGroup(byCode code: String) async throws -> Group? { nil }
    func sendJoinRequest(groupID: String, userID: String, username: String) async throws {}
    func fetchJoinRequests(groupID: String) async throws -> [JoinRequest] { [] }
    func acceptJoinRequest(requestID: String, groupID: String, userID: String) async throws {
        acceptedRequests.append((requestID, groupID, userID))
    }
    func declineJoinRequest(requestID: String) async throws {
        declinedRequestIDs.append(requestID)
    }
    func leaveGroup(groupID: String, userID: String) async throws {}
    func removeMember(groupID: String, userID: String) async throws {}
}

// MARK: - Mock Friend Repository (for inbox actions)

final class MockInboxFriendRepository: FriendRepository {
    var acceptedRequests: [String] = []
    var declinedRequestIDs: [String] = []

    func fetchFriends(userID: String) async throws -> [Friendship] { [] }
    func removeFriend(friendshipID: String) async throws {}
    func sendFriendRequest(senderID: String, receiverID: String,
                           senderUsername: String, receiverUsername: String) async throws {}
    func fetchIncomingRequests(userID: String) async throws -> [FriendRequest] { [] }
    func fetchOutgoingRequests(userID: String) async throws -> [FriendRequest] { [] }
    func acceptFriendRequest(_ request: FriendRequest) async throws -> Friendship {
        acceptedRequests.append(request.id)
        return Friendship(id: UUID().uuidString, userID1: request.senderID,
                         userID2: request.receiverID, createdAt: Date())
    }
    func declineFriendRequest(requestID: String) async throws {
        declinedRequestIDs.append(requestID)
    }
    func cancelFriendRequest(requestID: String) async throws {}
    func searchUsers(query: String, excludingUserID: String) async throws -> [UserProfile] { [] }
}

// MARK: - Tests

@MainActor
final class InboxViewModelTests: XCTestCase {

    private var mockInboxRepo: MockInboxRepository!
    private var mockGroupRepo: MockInboxGroupRepository!
    private var mockFriendRepo: MockInboxFriendRepository!
    private var mockProfileRepo: MockUserProfileRepository!
    private var mockCoordinator: MockSignInWithAppleCoordinator!
    private var authManager: AuthenticationManager!
    private var viewModel: InboxViewModel!

    override func setUp() {
        super.setUp()
        mockInboxRepo = MockInboxRepository()
        mockGroupRepo = MockInboxGroupRepository()
        mockFriendRepo = MockInboxFriendRepository()
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
            id: id, username: "user_\(id)", displayName: nil,
            createdAt: Date(), usernameEdited: false
        )
        await authManager.restoreSession()
        viewModel = InboxViewModel(
            inboxRepository: mockInboxRepo,
            groupRepository: mockGroupRepo,
            friendRepository: mockFriendRepo,
            authManager: authManager
        )
    }

    // MARK: - Fetch Tests

    func testFetchReturnsMessagesNewestFirst() async {
        await signInUser()
        let old = Date().addingTimeInterval(-3600)
        let recent = Date()

        mockInboxRepo.messages = [
            InboxMessage(id: "m1", recipientID: "test_user", type: .friendRequestAccepted,
                        payload: ["username": "alice"], isRead: false, createdAt: old),
            InboxMessage(id: "m2", recipientID: "test_user", type: .groupRequestAccepted,
                        payload: ["groupName": "Fitness"], isRead: false, createdAt: recent)
        ]

        await viewModel.fetchMessages()

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages.first?.id, "m2", "Newest should be first")
    }

    func testUnreadCountMatchesUnreadMessages() async {
        await signInUser()
        mockInboxRepo.messages = [
            InboxMessage(id: "m1", recipientID: "test_user", type: .friendRequestAccepted,
                        payload: [:], isRead: false, createdAt: Date()),
            InboxMessage(id: "m2", recipientID: "test_user", type: .groupDeleted,
                        payload: [:], isRead: true, createdAt: Date()),
            InboxMessage(id: "m3", recipientID: "test_user", type: .friendRequest,
                        payload: [:], isRead: false, createdAt: Date())
        ]

        await viewModel.fetchMessages()

        XCTAssertEqual(viewModel.unreadCount, 2)
    }

    // MARK: - Action Tests

    func testAcceptGroupJoinRequestCallsGroupRepo() async {
        await signInUser()
        let message = InboxMessage(
            id: "m1", recipientID: "test_user", type: .groupJoinRequest,
            payload: ["requestID": "req1", "groupID": "g1", "userID": "joiner", "username": "bob"],
            isRead: false, createdAt: Date()
        )
        mockInboxRepo.messages = [message]
        await viewModel.fetchMessages()

        await viewModel.performAction(.accept, on: message)

        XCTAssertEqual(mockGroupRepo.acceptedRequests.count, 1)
        XCTAssertEqual(mockGroupRepo.acceptedRequests.first?.requestID, "req1")
        XCTAssertEqual(mockGroupRepo.acceptedRequests.first?.groupID, "g1")
        XCTAssertTrue(viewModel.messages.isEmpty, "Message should be deleted after action")
    }

    func testDeclineGroupJoinRequestCallsGroupRepo() async {
        await signInUser()
        let message = InboxMessage(
            id: "m1", recipientID: "test_user", type: .groupJoinRequest,
            payload: ["requestID": "req1", "groupID": "g1", "userID": "joiner", "username": "bob"],
            isRead: false, createdAt: Date()
        )
        mockInboxRepo.messages = [message]
        await viewModel.fetchMessages()

        await viewModel.performAction(.decline, on: message)

        XCTAssertTrue(mockGroupRepo.declinedRequestIDs.contains("req1"))
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testAcceptFriendRequestCallsFriendRepo() async {
        await signInUser()
        let message = InboxMessage(
            id: "m1", recipientID: "test_user", type: .friendRequest,
            payload: ["requestID": "freq1", "senderID": "alice_id", "senderUsername": "alice"],
            isRead: false, createdAt: Date()
        )
        mockInboxRepo.messages = [message]
        await viewModel.fetchMessages()

        await viewModel.performAction(.accept, on: message)

        XCTAssertTrue(mockFriendRepo.acceptedRequests.contains("freq1"))
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testDeclineFriendRequestCallsFriendRepo() async {
        await signInUser()
        let message = InboxMessage(
            id: "m1", recipientID: "test_user", type: .friendRequest,
            payload: ["requestID": "freq1", "senderID": "alice_id", "senderUsername": "alice"],
            isRead: false, createdAt: Date()
        )
        mockInboxRepo.messages = [message]
        await viewModel.fetchMessages()

        await viewModel.performAction(.decline, on: message)

        XCTAssertTrue(mockFriendRepo.declinedRequestIDs.contains("freq1"))
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - Delete & Mark Read Tests

    func testDeleteMessageRemovesFromList() async {
        await signInUser()
        let message = InboxMessage(
            id: "m1", recipientID: "test_user", type: .groupDeleted,
            payload: ["groupName": "Old Group"], isRead: true, createdAt: Date()
        )
        mockInboxRepo.messages = [message]
        await viewModel.fetchMessages()
        XCTAssertEqual(viewModel.messages.count, 1)

        await viewModel.deleteMessage(message)

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(mockInboxRepo.deletedMessageIDs.contains("m1"))
    }

    func testMarkAllAsReadClearsUnread() async {
        await signInUser()
        mockInboxRepo.messages = [
            InboxMessage(id: "m1", recipientID: "test_user", type: .friendRequestAccepted,
                        payload: [:], isRead: false, createdAt: Date()),
            InboxMessage(id: "m2", recipientID: "test_user", type: .groupRequestAccepted,
                        payload: [:], isRead: false, createdAt: Date())
        ]
        await viewModel.fetchMessages()
        XCTAssertEqual(viewModel.unreadCount, 2)

        await viewModel.markAllAsRead()

        XCTAssertEqual(viewModel.unreadCount, 0)
        XCTAssertTrue(mockInboxRepo.markedAllAsReadUserIDs.contains("test_user"))
    }
}
