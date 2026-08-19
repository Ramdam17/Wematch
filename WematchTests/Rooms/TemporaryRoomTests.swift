import XCTest
@testable import Wematch

// MARK: - Spy Mocks

/// `@unchecked Sendable` justification: test-only. The stored state is written and
/// read from the main actor inside a single test method, and no instance outlives
/// the test that made it (plan 1.10).
final class MockRoomRepository: RoomRepository, @unchecked Sendable {
    // Test-only mock: single-threaded XCTest access, no real concurrency.
    var joinedRoomIDs: [String] = []
    var leftRoomIDs: [String] = []
    /// Thrown by the participants stream — a permission-denied listener, in practice.
    var observeError: Error?
    /// Thrown by every heart-rate write until cleared.
    var heartRateWriteError: Error?
    /// Connection values delivered in order; empty means "connected throughout".
    var connectionUpdates: [Bool] = []

    func joinRoom(roomID: String, participant: RoomParticipant) async throws {
        joinedRoomIDs.append(roomID)
    }

    func leaveRoom(roomID: String, userID: String) async throws {
        leftRoomIDs.append(roomID)
    }

    func updateHeartRate(roomID: String, userID: String, data: HeartRateData,
                         username: String, slot: HeartPaletteSlot) async throws {
        if let heartRateWriteError { throw heartRateWriteError }
    }

    func observeConnection() -> AsyncStream<Bool> {
        let updates = connectionUpdates
        return AsyncStream { continuation in
            for value in updates { continuation.yield(value) }
            continuation.finish()
        }
    }

    func observeParticipants(roomID: String) -> AsyncThrowingStream<[RoomParticipant], Error> {
        let error = observeError
        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}

/// `@unchecked Sendable` justification: test-only. The stored state is written and
/// read from the main actor inside a single test method, and no instance outlives
/// the test that made it (plan 1.10).
final class SpyTemporaryRoomRepository: TemporaryRoomRepository, @unchecked Sendable {
    // Test-only spy: single-threaded XCTest access.
    var hasParticipantsResult = false
    var deletedRoomIDs: [String] = []

    func createRoom(roomID: String, userA: String, userB: String,
                    userAUsername: String, userBUsername: String) async throws {}

    func fetchActiveRooms(userID: String) async throws -> [TemporaryRoom] { [] }

    func deleteRoom(roomID: String) async throws {
        deletedRoomIDs.append(roomID)
    }

    func hasParticipants(roomID: String) async throws -> Bool {
        hasParticipantsResult
    }
}

// FakeFirebaseService lives in WematchTests/Support/FakeFirebaseService.swift
// (shared with RoomLifecycleTests).

/// `@unchecked Sendable` justification: test-only. The stored state is written and
/// read from the main actor inside a single test method, and no instance outlives
/// the test that made it (plan 1.10).
final class MockHealthKitService: HealthKitServiceProtocol, @unchecked Sendable {

    /// Samples pushed in through the protocol, as the Watch relay does on a real device.
    /// Recorded rather than forwarded: the point of the seam is that a test can see what
    /// the ViewModel handed the heart-rate source without a Watch in the room.
    var relayedHeartRates: [Double] = []

    /// Beats to deliver. The first is emitted as soon as the stream is consumed; the
    /// rest wait for `emitNext()`, so a test can script "this write fails, the next
    /// one lands". Empty (the default) keeps the historical behaviour: no heart at all.
    var scriptedHeartRates: [Double] = []

    private var continuation: AsyncStream<Double>.Continuation?
    private var pending: [Double] = []

    func startHeartRateStreaming() -> AsyncStream<Double> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.pending = self.scriptedHeartRates
            if self.pending.isEmpty {
                continuation.finish()
            } else {
                continuation.yield(self.pending.removeFirst())
            }
        }
    }

    func emitNext() {
        guard !pending.isEmpty else { return }
        continuation?.yield(pending.removeFirst())
    }

    func yield(heartRate: Double) {
        relayedHeartRates.append(heartRate)
        continuation?.yield(heartRate)
    }

    func stopHeartRateStreaming() {
        continuation?.finish()
    }
}

/// `@unchecked Sendable` justification: test-only. The stored state is written and
/// read from the main actor inside a single test method, and no instance outlives
/// the test that made it (plan 1.10).
final class MockWatchService: WatchConnectivityServiceProtocol, @unchecked Sendable {
    var isReachable = false
    /// Messages the Watch "sends" as soon as the phone starts listening.
    var scriptedMessages: [WatchMessage] = []
    /// Thrown by `send` — how an unreachable Watch behaves since plan 1.7 (D1).
    var sendError: Error?
    var sentMessages: [WatchMessage] = []

    func activate() {}

    func send(_ message: WatchMessage) async throws {
        sentMessages.append(message)
        if let sendError { throw sendError }
    }

    func sendWithoutAcknowledgement(_ message: WatchMessage) {
        sentMessages.append(message)
    }

    func messages() -> AsyncStream<WatchMessage> {
        let scripted = scriptedMessages
        return AsyncStream { continuation in
            for message in scripted { continuation.yield(message) }
            continuation.finish()
        }
    }
}

// MARK: - Tests

@MainActor
final class TemporaryRoomTests: XCTestCase {

    // MARK: - Room ID construction

    func testRoomIDIsDeterministicRegardlessOfArgumentOrder() {
        let id1 = TemporaryRoom.roomID(userA: "alice", userB: "bob")
        let id2 = TemporaryRoom.roomID(userA: "bob", userB: "alice")
        XCTAssertEqual(id1, id2)
        XCTAssertEqual(id1, "temp_alice_bob")
    }

    func testRoomIDManglesDotsFromAppleSignInIDs() {
        // Apple Sign-In IDs contain dots; Firebase keys cannot.
        let id = TemporaryRoom.roomID(userA: "000123.abc", userB: "000456.def")
        XCTAssertEqual(id, "temp_000123_abc_000456_def")
        XCTAssertFalse(id.contains("."))
    }

    // MARK: - E1 regression (audit finding, CLOSED in plan 1.2c)
    //
    // Historical bug: exitRoom() re-derived participant IDs by splitting the
    // roomID on "_", truncating IDs whose safe form contained underscores.
    // Fixed by construction: deleteRoom(roomID:) resolves members from room
    // metadata; no caller can pass (wrong) IDs anymore.

    func testExitRoomDestroysTempRoomWhenLastParticipantLeaves() async {
        // Even with the worst historical case (dotted Apple IDs), cleanup
        // is keyed by roomID only.
        let rawA = "000123.abc"
        let rawB = "000456.def"
        let roomID = TemporaryRoom.roomID(userA: rawA, userB: rawB)

        // Signed-in user = userA
        let profileRepo = MockUserProfileRepository()
        let coordinator = MockSignInWithAppleCoordinator()
        coordinator.userIDToReturn = rawA
        // Profiles are keyed by the Firebase UID since plan 1.2.
        profileRepo.profiles["firebase_uid_mock"] = UserProfile(
            id: "firebase_uid_mock", username: "cosmic_panda0042",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )
        let authManager = AuthenticationManager(
            repository: profileRepo,
            coordinator: coordinator,
            keychain: InMemoryKeychain(),
            firebaseAuth: MockFirebaseAuthService()
        )
        await authManager.signInWithApple()

        let roomRepo = MockRoomRepository()
        let tempRepo = SpyTemporaryRoomRepository()
        tempRepo.hasParticipantsResult = false // last one out → must destroy the index

        let viewModel = RoomViewModel(
            roomID: roomID,
            roomName: "Temp room",
            roomRepository: roomRepo,
            tempRoomRepository: tempRepo,
            healthKitService: MockHealthKitService(),
            watchService: MockWatchService(),
            dashboardStore: InMemoryDashboardRecordStore(),
            authManager: authManager
        )

        await viewModel.enterRoom()
        XCTAssertEqual(roomRepo.joinedRoomIDs, [roomID])

        await viewModel.exitRoom()

        XCTAssertEqual(tempRepo.deletedRoomIDs, [roomID],
                       "Temp room must be destroyed when the last participant leaves")
    }

    // The true E1 regression test: with UID members stored in metadata, the
    // repository must remove BOTH index entries and the room node — resolved
    // from metadata, regardless of what the roomID string looks like.
    func testDeleteRoomResolvesMembersFromMetadataNotFromRoomID() async throws {
        let fake = FakeFirebaseService()
        let repo = FirebaseTemporaryRoomRepository(firebaseService: fake)

        // Firebase UIDs (no dots) — but also works with any opaque ID.
        let uidA = "uidAAAA1111"
        let uidB = "uidBBBB2222"
        let roomID = TemporaryRoom.roomID(userA: uidA, userB: uidB)

        try await repo.createRoom(roomID: roomID, userA: uidA, userB: uidB,
                                  userAUsername: "alice", userBUsername: "bob")
        try await repo.deleteRoom(roomID: roomID)

        XCTAssertTrue(fake.removedPaths.contains("tempRooms/\(uidA)/\(roomID)"),
                      "User A's index entry must be removed")
        XCTAssertTrue(fake.removedPaths.contains("tempRooms/\(uidB)/\(roomID)"),
                      "User B's index entry must be removed")
        XCTAssertTrue(fake.removedPaths.contains("rooms/\(roomID)"),
                      "Room node must be removed")
    }

    func testDeleteRoomWithoutMetadataStillRemovesRoomNode() async throws {
        let fake = FakeFirebaseService()
        let repo = FirebaseTemporaryRoomRepository(firebaseService: fake)

        // Legacy room: no metadata written.
        try await repo.deleteRoom(roomID: "temp_legacy_room")

        XCTAssertEqual(fake.removedPaths, ["rooms/temp_legacy_room"],
                       "Room node removed; unresolvable indexes are logged, not guessed")
    }
}
