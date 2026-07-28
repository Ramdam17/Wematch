import XCTest
@testable import Wematch

/// Lifecycle-pass tests (plan 1.4/1.5 — audit C1/C2): teardown must happen on
/// EVERY exit path, including with no session left, and the Firebase listener
/// chain must actually unwind on cancellation.
@MainActor
final class RoomLifecycleTests: XCTestCase {

    private func makeSignedInAuth() async -> (AuthenticationManager, MockFirebaseAuthService) {
        let profileRepo = MockUserProfileRepository()
        let mockFirebaseAuth = MockFirebaseAuthService()
        profileRepo.profiles["firebase_uid_mock"] = UserProfile(
            id: "firebase_uid_mock", username: "cosmic_panda0042",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        let auth = AuthenticationManager(
            repository: profileRepo,
            coordinator: MockSignInWithAppleCoordinator(),
            keychain: InMemoryKeychain(),
            firebaseAuth: mockFirebaseAuth
        )
        await auth.signInWithApple()
        return (auth, mockFirebaseAuth)
    }

    private func makeViewModel(auth: AuthenticationManager,
                               roomRepo: MockRoomRepository = MockRoomRepository(),
                               tempRepo: SpyTemporaryRoomRepository = SpyTemporaryRoomRepository(),
                               dashboardStore: InMemoryDashboardRecordStore = InMemoryDashboardRecordStore()
    ) -> RoomViewModel {
        RoomViewModel(
            roomID: "room1",
            roomName: "Test room",
            roomRepository: roomRepo,
            tempRoomRepository: tempRepo,
            healthKitService: MockHealthKitService(),
            watchService: MockWatchService(),
            // Injected, or the room would write real records into the test host's
            // Application Support on every run.
            dashboardStore: dashboardStore,
            authManager: auth
        )
    }

    // MARK: - Dashboard recording

    func testLeavingARoomRecordsTheSession() async {
        let (auth, _) = await makeSignedInAuth()
        let store = InMemoryDashboardRecordStore()
        let viewModel = makeViewModel(auth: auth, dashboardStore: store)

        await viewModel.enterRoom()
        await viewModel.exitRoom()

        let records = try? store.load()
        XCTAssertEqual(records?.sessions.count, 1, "a room the user actually entered must leave a trace")
        XCTAssertEqual(records?.sessions.first?.roomID, "room1")
        XCTAssertNotNil(records?.sessions.first?.leftAt, "the session has to be closed, not left open")
    }

    /// Sign-out mid-room is the scenario audit C1 was about; the local history it
    /// produced still belongs to the user, and writing it needs no session.
    func testASessionEndedBySignOutIsStillRecorded() async {
        let (auth, _) = await makeSignedInAuth()
        let store = InMemoryDashboardRecordStore()
        let viewModel = makeViewModel(auth: auth, dashboardStore: store)

        await viewModel.enterRoom()
        auth.signOut()
        await viewModel.exitRoom()

        XCTAssertEqual(try? store.load().sessions.count, 1)
    }

    func testAFailedWriteDoesNotBlockLeavingTheRoom() async {
        let (auth, _) = await makeSignedInAuth()
        let store = InMemoryDashboardRecordStore()
        store.appendError = NSError(domain: "disk", code: 28)
        let viewModel = makeViewModel(auth: auth, dashboardStore: store)

        await viewModel.enterRoom()
        await viewModel.exitRoom()

        XCTAssertEqual(store.appendCallCount, 1, "it must have tried")
        XCTAssertFalse(viewModel.isInRoom, "but a dashboard write must never trap the user in a room")
    }

    func testExitingWithoutEverEnteringRecordsNothing() async {
        let (auth, _) = await makeSignedInAuth()
        let store = InMemoryDashboardRecordStore()
        let viewModel = makeViewModel(auth: auth, dashboardStore: store)

        await viewModel.exitRoom()

        XCTAssertEqual(store.appendCallCount, 0)
    }

    // MARK: - C1: teardown without a session

    func testExitRoomAfterSignOutStillTearsDownLocally() async {
        let (auth, _) = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo)

        await viewModel.enterRoom()
        XCTAssertTrue(viewModel.isInRoom)

        // Sign out WHILE in the room — the historical zombie scenario.
        auth.signOut()
        await viewModel.exitRoom()

        XCTAssertFalse(viewModel.isInRoom, "Local teardown must not depend on a session")
        XCTAssertTrue(viewModel.participants.isEmpty)
        XCTAssertTrue(roomRepo.leftRoomIDs.isEmpty,
                      "No network cleanup without a session (onDisconnect reaps the node)")
    }

    func testExitRoomWithSessionDoesNetworkCleanup() async {
        let (auth, _) = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo)

        await viewModel.enterRoom()
        await viewModel.exitRoom()

        XCTAssertEqual(roomRepo.leftRoomIDs, ["room1"])
    }

    func testExitRoomIsIdempotent() async {
        let (auth, _) = await makeSignedInAuth()
        let roomRepo = MockRoomRepository()
        let viewModel = makeViewModel(auth: auth, roomRepo: roomRepo)

        await viewModel.enterRoom()
        await viewModel.exitRoom()
        await viewModel.exitRoom() // onDisappear fires after Leave — must be a no-op

        XCTAssertEqual(roomRepo.leftRoomIDs, ["room1"], "Second exit must not repeat cleanup")
    }

    // MARK: - C2: the listener chain actually unwinds

    func testObserveParticipantsUnwindsFirebaseObserverOnCancellation() async throws {
        let fake = FakeFirebaseService()
        fake.keepObserveOpen = true
        let repo = FirebaseRoomRepository(firebaseService: fake)

        let consumer = Task {
            for await _ in repo.observeParticipants(roomID: "room1") {}
        }

        // Let the observation chain spin up, then cancel the consumer —
        // the underlying Firebase observer must be removed (audit C2).
        try await Task.sleep(for: .milliseconds(100))
        consumer.cancel()
        _ = await consumer.value
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(fake.observeTerminations, ["rooms/room1/users"],
                       "Cancelling the consumer must unwind down to the Firebase observer")
    }
}
