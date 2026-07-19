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

    func deleteProfile(userID: String) async throws {
        profiles[userID] = nil
    }
}

final class MockSignInWithAppleCoordinator: SignInWithAppleCoordinator {
    var userIDToReturn: String = "mock_apple_user_id"
    var shouldThrow = false

    override func signIn() async throws -> AppleSignInResult {
        if shouldThrow {
            throw AuthenticationError.canceled
        }
        return AppleSignInResult(
            userID: userIDToReturn,
            identityToken: "mock_identity_token",
            rawNonce: "mock_raw_nonce"
        )
    }
}

// MARK: - Tests

@MainActor
final class AuthenticationManagerTests: XCTestCase {

    private var mockRepo: MockUserProfileRepository!
    private var mockCoordinator: MockSignInWithAppleCoordinator!
    private var keychain: InMemoryKeychain!
    private var mockFirebaseAuth: MockFirebaseAuthService!
    private var authManager: AuthenticationManager!

    override func setUp() {
        super.setUp()
        mockRepo = MockUserProfileRepository()
        mockCoordinator = MockSignInWithAppleCoordinator()
        keychain = InMemoryKeychain()
        mockFirebaseAuth = MockFirebaseAuthService()
        authManager = AuthenticationManager(
            repository: mockRepo,
            coordinator: mockCoordinator,
            keychain: keychain,
            firebaseAuth: mockFirebaseAuth
        )
    }

    func testSignInFederatesIntoFirebase() async {
        mockRepo.profiles["firebase_uid_mock"] = UserProfile(
            id: "firebase_uid_mock", username: "happy_dolphin1234",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        await authManager.signInWithApple()
        XCTAssertEqual(authManager.firebaseUID, "firebase_uid_mock")
    }

    func testFirebaseFederationFailureFailsSignIn() async {
        // Since plan 1.2 the Firebase UID IS the identity: no federation,
        // no session — and the failure must be loud.
        mockFirebaseAuth.shouldThrow = true
        await authManager.signInWithApple()
        XCTAssertNotEqual(authManager.authState, .signedIn)
        XCTAssertNil(authManager.firebaseUID)
        XCTAssertNil(authManager.currentUserID)
        XCTAssertNotNil(authManager.error, "Federation failure must be surfaced, not silent")
    }

    func testSignOutClearsFirebaseSession() async {
        await authManager.signInWithApple()
        authManager.signOut()
        XCTAssertNil(authManager.firebaseUID)
        XCTAssertEqual(mockFirebaseAuth.signOutCount, 1)
    }

    func testInitialStateIsUnknown() {
        XCTAssertEqual(authManager.authState, .unknown)
    }

    func testRestoreSessionWithEmptyKeychain() async {
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .signedOut)
    }

    func testRestoreSessionWithValidSessionsAndProfile() async {
        try? keychain.save(key: "appleUserID", value: "user123")
        mockFirebaseAuth.uid = "fb_user123"
        mockRepo.profiles["fb_user123"] = UserProfile(
            id: "fb_user123", username: "cosmic_panda0042",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .signedIn)
        XCTAssertEqual(authManager.userProfile?.username, "cosmic_panda0042")
        XCTAssertEqual(authManager.currentUserID, "fb_user123")
    }

    func testRestoreSessionWithoutFirebaseSessionSignsOut() async {
        // Apple marker present but Firebase session lost: identity is the
        // Firebase UID, so the user must sign in again.
        try? keychain.save(key: "appleUserID", value: "user123")
        mockFirebaseAuth.uid = nil
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .signedOut)
        XCTAssertNil(authManager.currentUserID)
    }

    func testRestoreSessionWithSessionsButNoProfile() async {
        try? keychain.save(key: "appleUserID", value: "user123")
        mockFirebaseAuth.uid = "fb_user123"
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .needsUsername)
    }

    func testSignInReturningUser() async {
        mockRepo.profiles["firebase_uid_mock"] = UserProfile(
            id: "firebase_uid_mock", username: "happy_dolphin1234",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        await authManager.signInWithApple()
        XCTAssertEqual(authManager.authState, .signedIn)
        XCTAssertEqual(authManager.userProfile?.username, "happy_dolphin1234")
        XCTAssertEqual(authManager.currentUserID, "firebase_uid_mock")
        XCTAssertEqual(authManager.appleUserID, "mock_apple_user_id")
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
        XCTAssertNotNil(mockRepo.profiles["firebase_uid_mock"],
                        "Profile must be keyed by the Firebase UID, not the Apple ID")
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
        try? keychain.save(key: "appleUserID", value: "user123")
        mockFirebaseAuth.uid = "fb_user123"
        mockRepo.profiles["fb_user123"] = UserProfile(
            id: "fb_user123", username: "test_user0001",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        await authManager.restoreSession()
        XCTAssertEqual(authManager.authState, .signedIn)

        authManager.signOut()
        XCTAssertEqual(authManager.authState, .signedOut)
        XCTAssertNil(authManager.userProfile)
        XCTAssertNil(authManager.currentUserID)
        XCTAssertNil(keychain.retrieve(key: "appleUserID"))
    }
}

// MARK: - AuthState Equatable

extension AuthState: Equatable {}
