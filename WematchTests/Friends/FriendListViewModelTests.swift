import XCTest
@testable import Wematch

// MARK: - Mock Repository

final class MockFriendRepository: FriendRepository {
    var friendships: [Friendship] = []
    var incomingRequests: [FriendRequest] = []
    var outgoingRequests: [FriendRequest] = []
    var users: [UserProfile] = []
    var acceptedRequestIDs: [String] = []
    var declinedRequestIDs: [String] = []
    var canceledRequestIDs: [String] = []
    var removedFriendshipIDs: [String] = []
    var sentRequests: [(senderID: String, receiverID: String)] = []
    var shouldThrowOnSend: FriendError?

    func fetchFriends(userID: String) async throws -> [Friendship] {
        friendships.filter { $0.userID1 == userID || $0.userID2 == userID }
    }

    func removeFriend(friendshipID: String) async throws {
        removedFriendshipIDs.append(friendshipID)
        friendships.removeAll { $0.id == friendshipID }
    }

    func sendFriendRequest(senderID: String, receiverID: String,
                           senderUsername: String, receiverUsername: String) async throws {
        if let error = shouldThrowOnSend { throw error }
        sentRequests.append((senderID, receiverID))
        outgoingRequests.append(FriendRequest(
            id: UUID().uuidString, senderID: senderID, receiverID: receiverID,
            senderUsername: senderUsername, receiverUsername: receiverUsername,
            status: .pending, createdAt: Date()
        ))
    }

    func fetchIncomingRequests(userID: String) async throws -> [FriendRequest] {
        incomingRequests.filter { $0.receiverID == userID && $0.status == .pending }
    }

    func fetchOutgoingRequests(userID: String) async throws -> [FriendRequest] {
        outgoingRequests.filter { $0.senderID == userID && $0.status == .pending }
    }

    func acceptFriendRequest(_ request: FriendRequest) async throws -> Friendship {
        acceptedRequestIDs.append(request.id)
        incomingRequests.removeAll { $0.id == request.id }
        let friendship = Friendship(
            id: UUID().uuidString,
            userID1: request.senderID,
            userID2: request.receiverID,
            createdAt: Date()
        )
        friendships.append(friendship)
        return friendship
    }

    func declineFriendRequest(requestID: String) async throws {
        declinedRequestIDs.append(requestID)
        incomingRequests.removeAll { $0.id == requestID }
    }

    func cancelFriendRequest(requestID: String) async throws {
        canceledRequestIDs.append(requestID)
        outgoingRequests.removeAll { $0.id == requestID }
    }

    func searchUsers(query: String, excludingUserID: String) async throws -> [UserProfile] {
        users.filter {
            $0.id != excludingUserID &&
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Mock Inbox Repository

final class MockInboxMessageRepository: InboxMessageRepository {
    var messages: [(recipientID: String, type: InboxMessageType, payload: [String: String])] = []

    func createMessage(recipientID: String, type: InboxMessageType, payload: [String: String]) async throws {
        messages.append((recipientID, type, payload))
    }
}

// MARK: - Tests

@MainActor
final class FriendListViewModelTests: XCTestCase {

    private var mockRepo: MockFriendRepository!
    private var mockProfileRepo: MockUserProfileRepository!
    private var mockInboxRepo: MockInboxMessageRepository!
    private var mockCoordinator: MockSignInWithAppleCoordinator!
    private var authManager: AuthenticationManager!
    private var viewModel: FriendListViewModel!

    override func setUp() {
        super.setUp()
        mockRepo = MockFriendRepository()
        mockProfileRepo = MockUserProfileRepository()
        mockInboxRepo = MockInboxMessageRepository()
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
        viewModel = FriendListViewModel(
            repository: mockRepo,
            profileRepository: mockProfileRepo,
            inboxRepository: mockInboxRepo,
            authManager: authManager
        )
    }

    func testFetchFriendsReturnsList() async {
        await signInUser()
        mockRepo.friendships = [
            Friendship(id: "f1", userID1: "test_user", userID2: "friend_a", createdAt: Date()),
            Friendship(id: "f2", userID1: "friend_b", userID2: "test_user", createdAt: Date())
        ]
        mockProfileRepo.profiles["friend_a"] = UserProfile(
            id: "friend_a", username: "alice", displayName: nil, createdAt: Date(), usernameEdited: false
        )
        mockProfileRepo.profiles["friend_b"] = UserProfile(
            id: "friend_b", username: "bob", displayName: nil, createdAt: Date(), usernameEdited: false
        )

        await viewModel.fetchAll()

        XCTAssertEqual(viewModel.friends.count, 2)
        XCTAssertNotNil(viewModel.friendProfile(for: viewModel.friends[0]))
    }

    func testAcceptRequestCreatesFriendship() async {
        await signInUser()
        let request = FriendRequest(
            id: "req1", senderID: "sender", receiverID: "test_user",
            senderUsername: "sender_user", receiverUsername: "user_test_user",
            status: .pending, createdAt: Date()
        )
        mockRepo.incomingRequests = [request]
        await viewModel.fetchAll()
        XCTAssertEqual(viewModel.incomingRequests.count, 1)

        await viewModel.acceptRequest(request)

        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
        XCTAssertEqual(viewModel.friends.count, 1)
        XCTAssertTrue(mockRepo.acceptedRequestIDs.contains("req1"))
        XCTAssertEqual(mockInboxRepo.messages.count, 1)
        XCTAssertEqual(mockInboxRepo.messages.first?.type, .friendRequestAccepted)
    }

    func testDeclineRequestRemovesFromList() async {
        await signInUser()
        let request = FriendRequest(
            id: "req1", senderID: "sender", receiverID: "test_user",
            senderUsername: "sender_user", receiverUsername: "user_test_user",
            status: .pending, createdAt: Date()
        )
        mockRepo.incomingRequests = [request]
        await viewModel.fetchAll()

        await viewModel.declineRequest(request)

        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
        XCTAssertTrue(mockRepo.declinedRequestIDs.contains("req1"))
        XCTAssertEqual(mockInboxRepo.messages.first?.type, .friendRequestDeclined)
    }

    func testRemoveFriendDeletesFriendship() async {
        await signInUser()
        mockRepo.friendships = [
            Friendship(id: "f1", userID1: "test_user", userID2: "friend_a", createdAt: Date())
        ]
        await viewModel.fetchAll()
        XCTAssertEqual(viewModel.friends.count, 1)

        await viewModel.removeFriend(friendshipID: "f1")

        XCTAssertTrue(viewModel.friends.isEmpty)
        XCTAssertTrue(mockRepo.removedFriendshipIDs.contains("f1"))
    }

    func testCancelOutgoingRequest() async {
        await signInUser()
        mockRepo.outgoingRequests = [
            FriendRequest(
                id: "req1", senderID: "test_user", receiverID: "other",
                senderUsername: "user_test_user", receiverUsername: "other_user",
                status: .pending, createdAt: Date()
            )
        ]
        await viewModel.fetchAll()
        XCTAssertEqual(viewModel.outgoingRequests.count, 1)

        await viewModel.cancelRequest(viewModel.outgoingRequests[0])

        XCTAssertTrue(viewModel.outgoingRequests.isEmpty)
        XCTAssertTrue(mockRepo.canceledRequestIDs.contains("req1"))
    }

    func testFriendshipIsBidirectional() {
        let friendship = Friendship(id: "f1", userID1: "alice", userID2: "bob", createdAt: Date())
        XCTAssertEqual(friendship.friendID(for: "alice"), "bob")
        XCTAssertEqual(friendship.friendID(for: "bob"), "alice")
    }
}
