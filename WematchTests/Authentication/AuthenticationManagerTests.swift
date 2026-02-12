import XCTest
@testable import Wematch

// MARK: - Mocks

final class MockUserProfileRepository: UserProfileRepository {
    var profiles: [String: UserProfile] = [:]
    var takenUsernames: Set<String> = []

    func fetchProfile(userID: String) async throws -> UserProfile? {
        profiles[userID]
    }

    func createProfile(_ profile: UserProfile) async throws {
        profiles[profile.id] = profile
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        !takenUsernames.contains(username)
    }
}

final class MockSignInWithAppleCoordinator: SignInWithAppleCoordinator {
    var userIDToReturn: String = "mock_apple_user_id"
    var shouldThrow = false

    override func signIn() async throws -> String {
        if shouldThrow {
            throw AuthenticationError.canceled
        }
        return userIDToReturn
    }
}

// MARK: - Tests

@MainActor
final class AuthenticationManagerTests: XCTestCase {

    private var mockRepo: MockUserProfileRepository!
    private var mockCoordinator: MockSignInWithAppleCoordinator!
    private var authManager: AuthenticationManager!

    override func setUp() {
        super.setUp()
        mockRepo = MockUserProfileRepository()
        mockCoordinator = MockSignInWithAppleCoordinator()
        authManager = AuthenticationManager(
            repository: mockRepo,
            coordinator: mockCoordinator
        )
    }

    override func tearDown() {
        try? KeychainService.delete(key: "appleUserID")
        super.tearDown()
    }

    func testInitialStateIsUnknown() {
        XCTAssertEqual(authManager.authState, .unknown)
    }

    func testRestoreSessionWithEmptyKeychain() async {
        try? KeychainService.delete(key: "appleUserID")
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .signedOut)
    }

    func testRestoreSessionWithValidKeychainAndProfile() async {
        try? KeychainService.save(key: "appleUserID", value: "user123")
        mockRepo.profiles["user123"] = UserProfile(
            id: "user123", username: "cosmic_panda0042",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .signedIn)
        XCTAssertEqual(authManager.userProfile?.username, "cosmic_panda0042")
    }

    func testRestoreSessionWithKeychainButNoProfile() async {
        try? KeychainService.save(key: "appleUserID", value: "user123")
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .needsUsername)
    }

    func testSignInReturningUser() async {
        mockRepo.profiles["mock_apple_user_id"] = UserProfile(
            id: "mock_apple_user_id", username: "happy_dolphin1234",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        await authManager.signInWithApple()
        XCTAssertEqual(authManager.authState, .signedIn)
        XCTAssertEqual(authManager.userProfile?.username, "happy_dolphin1234")
    }

    func testSignInFirstTimeUser() async {
        await authManager.signInWithApple()
        XCTAssertEqual(authManager.authState, .needsUsername)
        XCTAssertFalse(authManager.generatedUsername.isEmpty)
    }

    func testSignInCanceled() async {
        mockCoordinator.shouldThrow = true
        await authManager.signInWithApple()
        XCTAssertEqual(authManager.authState, .unknown)
        XCTAssertNil(authManager.error)
    }

    func testConfirmUsernameAvailable() async {
        mockCoordinator.userIDToReturn = "new_user"
        await authManager.signInWithApple()
        XCTAssertEqual(authManager.authState, .needsUsername)

        await authManager.confirmUsername()
        XCTAssertEqual(authManager.authState, .signedIn)
        XCTAssertNotNil(authManager.userProfile)
        XCTAssertNotNil(mockRepo.profiles["new_user"])
    }

    func testConfirmUsernameTaken() async {
        mockCoordinator.userIDToReturn = "new_user"
        await authManager.signInWithApple()

        let originalUsername = authManager.generatedUsername
        mockRepo.takenUsernames.insert(originalUsername)

        await authManager.confirmUsername()
        XCTAssertEqual(authManager.authState, .needsUsername)
        XCTAssertNotNil(authManager.error)
        XCTAssertNotEqual(authManager.generatedUsername, originalUsername,
                          "Should auto-shuffle after taken username")
    }

    func testShuffleUsername() async {
        mockCoordinator.userIDToReturn = "new_user"
        await authManager.signInWithApple()

        let first = authManager.generatedUsername
        authManager.shuffleUsername()
        let second = authManager.generatedUsername

        XCTAssertFalse(first.isEmpty)
        XCTAssertFalse(second.isEmpty)
    }

    func testSignOut() async {
        try? KeychainService.save(key: "appleUserID", value: "user123")
        mockRepo.profiles["user123"] = UserProfile(
            id: "user123", username: "test_user0001",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .signedIn)

        authManager.signOut()
        XCTAssertEqual(authManager.authState, .signedOut)
        XCTAssertNil(authManager.userProfile)
        XCTAssertNil(authManager.currentUserID)
        XCTAssertNil(KeychainService.retrieve(key: "appleUserID"))
    }
}

// MARK: - AuthState Equatable

extension AuthState: Equatable {}
