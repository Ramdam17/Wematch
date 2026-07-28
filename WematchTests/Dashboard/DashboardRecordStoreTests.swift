import XCTest
@testable import Wematch

/// Pins the on-device store: the history has to survive relaunches, grow by appending,
/// and disappear completely when the account does.
final class DashboardRecordStoreTests: XCTestCase {

    private var directory: URL!
    private let origin = Date(timeIntervalSince1970: 3_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DashboardRecordStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    // MARK: - Round trip

    func testLoadingBeforeAnythingIsWrittenIsEmptyNotAnError() throws {
        XCTAssertEqual(try makeStore().load(), .empty)
    }

    func testRecordsSurviveAFreshStoreOverTheSameFile() throws {
        try makeStore().append(sampleRecords())

        // A second store reading the same file stands in for the next app launch.
        let reloaded = try makeStore().load()

        XCTAssertEqual(reloaded.sessions.count, 1)
        XCTAssertEqual(reloaded.syncEvents.count, 1)
        XCTAssertEqual(reloaded.sessions.first?.starsSpawned, 7)
        XCTAssertEqual(reloaded.syncEvents.first?.duration, 60)
        XCTAssertEqual(reloaded.displayNames["a"], "brave_otter")
    }

    func testAppendingAccumulatesRatherThanReplacing() throws {
        let store = makeStore()

        try store.append(sampleRecords(suffix: "1"))
        try store.append(sampleRecords(suffix: "2"))

        let stored = try store.load()
        XCTAssertEqual(stored.sessions.count, 2)
        XCTAssertEqual(stored.syncEvents.count, 2)
    }

    func testALaterNameWinsSoARenamePropagates() throws {
        let store = makeStore()

        try store.append(DashboardRecords(displayNames: ["a": "old_name"]))
        try store.append(DashboardRecords(displayNames: ["a": "new_name"]))

        XCTAssertEqual(try store.load().displayNames["a"], "new_name")
    }

    func testAppendingNothingDoesNotCreateAFile() throws {
        try makeStore().append(.empty)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("dashboard-records.json").path)
        )
    }

    // MARK: - Deletion

    func testDeleteAllLeavesNothingBehind() throws {
        let store = makeStore()
        try store.append(sampleRecords())

        try store.deleteAll()

        XCTAssertEqual(try store.load(), .empty)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("dashboard-records.json").path),
            "account deletion must remove the file, not just blank its contents"
        )
    }

    func testDeletingWhenThereIsNothingToDeleteIsNotAnError() throws {
        XCTAssertNoThrow(try makeStore().deleteAll())
    }

    // MARK: - Forward compatibility

    /// A session written before `starsSpawned` existed must still decode. Losing a whole
    /// history to one added field is not an acceptable failure mode.
    func testASessionWrittenWithoutStarsDecodesAsZero() throws {
        let json = """
        {
          "sessions": [{
            "id": "old",
            "roomID": "room",
            "userID": "me",
            "joinedAt": "1970-02-05T17:20:00Z",
            "leftAt": "1970-02-05T17:30:00Z"
          }],
          "syncEvents": [],
          "displayNames": {}
        }
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("dashboard-records.json"))

        let stored = try makeStore().load()

        XCTAssertEqual(stored.sessions.count, 1)
        XCTAssertEqual(stored.sessions.first?.starsSpawned, 0)
    }

    // MARK: - Helpers

    private func makeStore() -> DashboardRecordStore {
        DashboardRecordStore(directory: directory)
    }

    private func sampleRecords(suffix: String = "") -> DashboardRecords {
        DashboardRecords(
            sessions: [
                SessionLog(
                    id: "session\(suffix)",
                    roomID: "room",
                    userID: "me",
                    joinedAt: origin,
                    leftAt: origin.addingTimeInterval(300),
                    starsSpawned: 7
                )
            ],
            syncEvents: [
                SyncEvent(
                    id: "event\(suffix)",
                    roomID: "room",
                    userIDs: ["me", "a"],
                    startedAt: origin,
                    endedAt: origin.addingTimeInterval(60)
                )
            ],
            displayNames: ["a": "brave_otter"]
        )
    }
}
