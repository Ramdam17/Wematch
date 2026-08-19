import XCTest
@testable import Wematch

/// Plan 1.7. The other half of `RoomConnectionStateTests`: the room actually notices.
/// Before this, a Firebase stream that died on a permission error and a room where
/// nobody spoke produced identical state.
@MainActor
final class RoomConnectionWiringTests: XCTestCase {

    private func makeSignedInAuth() async -> AuthenticationManager {
        let profileRepo = MockUserProfileRepository()
        profileRepo.profiles["firebase_uid_mock"] = UserProfile(
            id: "firebase_uid_mock", username: "cosmic_panda0042",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        let auth = AuthenticationManager(
            repository: profileRepo,
            coordinator: MockSignInWithAppleCoordinator(),
            keychain: InMemoryKeychain(),
            firebaseAuth: MockFirebaseAuthService()
        )
        await auth.signInWithApple()
        return auth
    }

    private func makeViewModel(auth: AuthenticationManager,
                               roomRepo: MockRoomRepository,
                               healthKit: MockHealthKitService = MockHealthKitService(),
                               watch: MockWatchService = MockWatchService()) -> RoomViewModel {
        RoomViewModel(
            roomID: "room1", roomName: "Test room",
            roomRepository: roomRepo,
            tempRoomRepository: SpyTemporaryRoomRepository(),
            healthKitService: healthKit,
            watchService: watch,
            dashboardStore: InMemoryDashboardRecordStore(),
            authManager: auth
        )
    }

    /// The state is computed from streams that settle a tick after `enterRoom` returns.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(150))
    }

    // MARK: - The room stream dies

    func testAFailedParticipantStreamIsSurfacedNotSwallowed() async throws {
        let auth = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        roomRepo.observeError = NSError(domain: "FIRDatabaseErrorDomain", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo)

        await viewModel.enterRoom()
        try await settle()

        XCTAssertEqual(viewModel.connectionState, .roomUnreachable,
                       "a permission-denied stream must not look like an empty room")
    }

    func testAHealthyParticipantStreamLeavesTheRoomConnected() async throws {
        let auth = await makeSignedInAuth()
        let viewModel = makeViewModel(auth: auth, roomRepo: MockRoomRepository())

        await viewModel.enterRoom()
        try await settle()

        XCTAssertEqual(viewModel.connectionState, .connected)
    }

    func testLeavingTheRoomClearsTheFailure() async throws {
        let auth = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        roomRepo.observeError = NSError(domain: "FIRDatabaseErrorDomain", code: 1)
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo)

        await viewModel.enterRoom()
        try await settle()
        await viewModel.exitRoom()

        XCTAssertEqual(viewModel.connectionState, .connected,
                       "a room we are no longer in has no connection to complain about")
    }

    // MARK: - The network goes away (field-test case S8)

    func testLosingTheNetworkIsSurfaced() async throws {
        let auth = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        roomRepo.connectionUpdates = [false]
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo)

        await viewModel.enterRoom()
        try await settle()

        XCTAssertEqual(viewModel.connectionState, .offline,
                       "airplane mode never cancels a listener — only .info/connected sees it")
    }

    func testTheBannerGoesAwayWhenTheNetworkComesBack() async throws {
        let auth = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        roomRepo.connectionUpdates = [false, true]
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo)

        await viewModel.enterRoom()
        try await settle()

        XCTAssertEqual(viewModel.connectionState, .connected)
    }

    // MARK: - Our own heart stops reaching the room

    func testAFailedHeartRateWriteIsSurfaced() async throws {
        let auth = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        roomRepo.heartRateWriteError = NSError(domain: "FIRDatabaseErrorDomain", code: 2)
        let healthKit = MockHealthKitService()
        healthKit.scriptedHeartRates = [72]
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo, healthKit: healthKit)

        await viewModel.enterRoom()
        try await settle()

        XCTAssertEqual(viewModel.connectionState, .notSharing)
    }

    func testOneSuccessfulWriteClearsTheWarning() async throws {
        let auth = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        roomRepo.heartRateWriteError = NSError(domain: "FIRDatabaseErrorDomain", code: 2)
        let healthKit = MockHealthKitService()
        healthKit.scriptedHeartRates = [72, 74]
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo, healthKit: healthKit)

        await viewModel.enterRoom()
        // The first write fails, then the network comes back.
        roomRepo.heartRateWriteError = nil
        healthKit.emitNext()
        try await settle()

        XCTAssertEqual(viewModel.connectionState, .connected)
    }

    // MARK: - The Watch says its feed is dead

    func testASilentWatchFeedReachesTheRoomState() async throws {
        let auth = await makeSignedInAuth()
        let watch = MockWatchService()
        watch.scriptedMessages = [.heartRateStatus(.silent)]
        let viewModel = makeViewModel(auth: auth, roomRepo: MockRoomRepository(), watch: watch)

        await viewModel.enterRoom()
        try await settle()

        XCTAssertEqual(viewModel.connectionState, .heartRateUnavailable(.silent))
    }
}
