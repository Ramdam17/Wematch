import XCTest
@testable import Wematch

// MARK: - Spy Mocks

final class MockRoomRepository: RoomRepository, @unchecked Sendable {
    // Test-only mock: single-threaded XCTest access, no real concurrency.
    var joinedRoomIDs: [String] = []
    var leftRoomIDs: [String] = []

    func joinRoom(roomID: String, participant: RoomParticipant) async throws {
        joinedRoomIDs.append(roomID)
    }

    func leaveRoom(roomID: String, userID: String) async throws {
        leftRoomIDs.append(roomID)
    }

    func updateHeartRate(roomID: String, userID: String, data: HeartRateData,
                         username: String, color: String) async throws {}

    func observeParticipants(roomID: String) -> AsyncStream<[RoomParticipant]> {
        AsyncStream { $0.finish() }
    }
}

final class SpyTemporaryRoomRepository: TemporaryRoomRepository, @unchecked Sendable {
    // Test-only spy: single-threaded XCTest access.
    var hasParticipantsResult = false
    var deletedRooms: [(roomID: String, userA: String, userB: String)] = []

    func createRoom(roomID: String, userA: String, userB: String,
                    userAUsername: String, userBUsername: String) async throws {}

    func fetchActiveRooms(userID: String) async throws -> [TemporaryRoom] { [] }

    func deleteRoom(roomID: String, userA: String, userB: String) async throws {
        deletedRooms.append((roomID, userA, userB))
    }

    func hasParticipants(roomID: String) async throws -> Bool {
        hasParticipantsResult
    }
}

final class MockHealthKitService: HealthKitServiceProtocol, @unchecked Sendable {
    var isAuthorized = true
    func requestAuthorization() async throws {}
    func startHeartRateStreaming() -> AsyncStream<Double> {
        AsyncStream { $0.finish() }
    }
    func stopHeartRateStreaming() {}
}

final class MockWatchService: WatchConnectivityServiceProtocol, @unchecked Sendable {
    var isReachable = false
    func activate() {}
    func send(message: [String: Any]) async throws {}
    var receivedMessages: AsyncStream<[String: Any]> {
        AsyncStream { $0.finish() }
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

    // MARK: - E1 reproduction (audit finding)
    //
    // exitRoom() re-derives the two participant IDs by splitting the roomID
    // suffix on "_" with maxSplits: 1. With real (dotted) Apple IDs the safe
    // form itself contains underscores, so the split truncates the first ID
    // and pollutes the second → deleteRoom is called with wrong IDs and the
    // temp-room index entries are orphaned in Firebase.
    //
    // EXPECTED TO FAIL until plan step 1.9 (store member IDs in room metadata
    // instead of parsing path keys) is implemented.

    func testExitRoomDeletesTempRoomWithCorrectSafeIDs() async {
        // Two realistic Apple Sign-In IDs (dots included)
        let rawA = "000123.abc"
        let rawB = "000456.def"
        let safeA = rawA.firebaseSafe() // "000123_abc"
        let safeB = rawB.firebaseSafe() // "000456_def"
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
            authManager: authManager
        )

        await viewModel.enterRoom()
        XCTAssertEqual(roomRepo.joinedRoomIDs, [roomID])

        await viewModel.exitRoom()

        XCTAssertEqual(tempRepo.deletedRooms.count, 1,
                       "Temp room index must be destroyed when the last participant leaves")
        let deleted = tempRepo.deletedRooms[0]
        XCTAssertEqual(deleted.roomID, roomID)
        // E1: current parsing yields userA = "000123", userB = "abc_000456_def".
        // XCTExpectFailure keeps CI green while documenting the bug; once plan 1.9
        // lands, this reports "unexpectedly passed" and the expectation must go.
        XCTExpectFailure("Known bug E1 — temp-room ID parsing truncates dotted Apple IDs (fix: plan 1.9)") {
            XCTAssertEqual(Set([deleted.userA, deleted.userB]), Set([safeA, safeB]),
                           "deleteRoom must receive the two firebaseSafe participant IDs intact")
        }
    }
}
