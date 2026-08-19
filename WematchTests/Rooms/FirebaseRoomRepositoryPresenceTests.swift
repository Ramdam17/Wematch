import XCTest
import WematchCore
@testable import Wematch

/// The `onDisconnect` hook is presence: it is what removes a participant whose phone
/// died mid-room. It used to be reached by downcasting the injected protocol to the
/// concrete service, so no test could see it. Now it is on the protocol, and this is the
/// test that could not exist before.
@MainActor
final class FirebaseRoomRepositoryPresenceTests: XCTestCase {

    private let participant = RoomParticipant(
        id: "user.one", username: "cosmic_panda0042", currentHR: 72, previousHR: 70,
        slot: HeartPaletteSlot(userID: "user.one")
    )

    /// Dots are mangled on the wire; the hook must be armed on the mangled path, the one
    /// the entry was actually written to.
    private let expectedPath = "rooms/room1/users/user_one"

    func testJoiningArmsTheHookOnTheWrittenPath() async throws {
        let fake = FakeFirebaseService()
        let repo = FirebaseRoomRepository(firebaseService: fake)

        try await repo.joinRoom(roomID: "room1", participant: participant)

        XCTAssertEqual(fake.armedPaths, [expectedPath])
        XCTAssertNotNil(fake.storage[expectedPath], "armed on the same path as the entry")
    }

    func testAJoinWhoseHookDoesNotArmThrows() async {
        let fake = FakeFirebaseService()
        fake.armError = NSError(domain: "rtdb", code: 1)
        let repo = FirebaseRoomRepository(firebaseService: fake)

        do {
            try await repo.joinRoom(roomID: "room1", participant: participant)
            XCTFail("a hook the server refused must not pass for a successful join")
        } catch {
            XCTAssertNotNil(fake.storage[expectedPath],
                            "the entry was written before the hook failed — the caller decides")
        }
    }

    func testLeavingRemovesThenDisarms() async throws {
        let fake = FakeFirebaseService()
        let repo = FirebaseRoomRepository(firebaseService: fake)

        try await repo.joinRoom(roomID: "room1", participant: participant)
        try await repo.leaveRoom(roomID: "room1", userID: "user.one")

        XCTAssertEqual(fake.callLog,
                       ["arm:\(expectedPath)", "remove:\(expectedPath)", "disarm:\(expectedPath)"],
                       "remove before disarm — an orphaned hook is harmless, a skipped remove is a ghost")
        XCTAssertNil(fake.storage[expectedPath])
    }
}
