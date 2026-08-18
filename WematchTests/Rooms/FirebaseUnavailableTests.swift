import XCTest
@testable import Wematch

/// Plan 1.7. Without a configured Firebase the app used to substitute an in-memory
/// mock and carry on — in release too. The room then showed a plot built entirely out
/// of local state: the most convincing lie the app can tell. Every entry point now
/// fails, and says which one.
final class FirebaseUnavailableTests: XCTestCase {

    private let service = FirebaseRealtimeService(database: nil)

    func testWritingWithoutFirebaseThrows() async {
        do {
            try await service.write(path: "rooms/room1/users/u1", value: ["currentHR": 72])
            XCTFail("a write that reached nothing must not report success")
        } catch {
            XCTAssertEqual(error as? RoomError, .firebaseUnavailable)
        }
    }

    func testReadingWithoutFirebaseThrows() async {
        do {
            _ = try await service.read(path: "rooms/room1/metadata")
            XCTFail("an empty dictionary is indistinguishable from an empty room")
        } catch {
            XCTAssertEqual(error as? RoomError, .firebaseUnavailable)
        }
    }

    func testRemovingWithoutFirebaseThrows() async {
        do {
            try await service.remove(path: "rooms/room1/users/u1")
            XCTFail("leaving a room that was never joined must not report success")
        } catch {
            XCTAssertEqual(error as? RoomError, .firebaseUnavailable)
        }
    }

    func testObservingWithoutFirebaseThrows() async {
        do {
            for try await _ in service.observe(path: "rooms/room1/users") {
                XCTFail("nothing can arrive from a database that is not there")
            }
            XCTFail("the stream must fail, not finish quietly")
        } catch {
            XCTAssertEqual(error as? RoomError, .firebaseUnavailable)
        }
    }
}
