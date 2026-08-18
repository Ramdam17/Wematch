import XCTest
@testable import Wematch

/// Pins what crosses to the Watch.
///
/// The Watch cannot recompute any of this — it has no history and no aggregation. If the
/// snapshot is wrong or the wire keys drift, the Watch has no way to notice.
final class WatchDashboardSnapshotTests: XCTestCase {

    private let origin = Date(timeIntervalSince1970: 4_000_000)
    private let me = "me"

    func testAnEmptyHistoryProducesAnEmptySnapshot() {
        let snapshot = WatchDashboardSnapshot.make(from: .empty, userID: me, asOf: origin)

        XCTAssertEqual(snapshot, .empty)
    }

    func testTheSnapshotResolvesTheBestPartnersNameAndSlot() {
        let records = DashboardRecords(
            sessions: [session(stars: 12)],
            syncEvents: [
                event(["a"], from: 0, to: 300),
                event(["b"], from: 400, to: 500)
            ],
            displayNames: ["a": "brave_otter", "b": "snowy_goldfish"]
        )

        let snapshot = WatchDashboardSnapshot.make(from: records, userID: me, asOf: origin)

        XCTAssertEqual(snapshot.bestPartnerName, "brave_otter")
        XCTAssertEqual(snapshot.bestPartnerSlot, HeartPaletteSlot(userID: "a").index,
                       "the slot must be derivable the same way everywhere, or the colour moves")
        XCTAssertEqual(snapshot.starsMade, 12)
        XCTAssertEqual(snapshot.biggestCluster, 2)
    }

    func testStarsComeFromTheSessionsNotTheEventCount() {
        let records = DashboardRecords(
            sessions: [session(stars: 3), session(stars: 4)],
            syncEvents: [
                event(["a"], from: 0, to: 10),
                event(["a"], from: 20, to: 30),
                event(["a"], from: 40, to: 50)
            ]
        )

        let snapshot = WatchDashboardSnapshot.make(from: records, userID: me, asOf: origin)

        XCTAssertEqual(snapshot.starsMade, 7, "three cluster events are not seven stars")
    }

    func testConnectedSecondsIsTheUnion() {
        let records = DashboardRecords(
            sessions: [],
            syncEvents: [
                event(["a"], from: 0, to: 600),
                event(["b"], from: 0, to: 600)
            ]
        )

        let snapshot = WatchDashboardSnapshot.make(from: records, userID: me, asOf: origin)

        XCTAssertEqual(snapshot.connectedSeconds, 600, "not 1200 — it is the same ten minutes")
    }

    func testAPartnerWithNoRememberedNameLeavesTheNameOutButKeepsTheRest() {
        let records = DashboardRecords(
            sessions: [],
            syncEvents: [event(["ghost"], from: 0, to: 100)],
            displayNames: [:]
        )

        let snapshot = WatchDashboardSnapshot.make(from: records, userID: me, asOf: origin)

        XCTAssertNil(snapshot.bestPartnerName)
        XCTAssertEqual(snapshot.biggestCluster, 2, "the rest of the dashboard still stands")
    }

    // MARK: - Wire format

    func testThePayloadCarriesEveryFieldItHasAValueFor() {
        let snapshot = WatchDashboardSnapshot(
            bestPartnerName: "brave_otter",
            bestPartnerSlot: 7,
            starsMade: 128,
            connectedSeconds: 13_320,
            biggestCluster: 5
        )

        let payload = snapshot.messagePayload

        XCTAssertEqual(payload["bestPartnerName"] as? String, "brave_otter")
        XCTAssertEqual(payload["bestPartnerSlot"] as? Int, 7)
        XCTAssertEqual(payload["starsMade"] as? Int, 128)
        XCTAssertEqual(payload["connectedSeconds"] as? TimeInterval, 13_320)
        XCTAssertEqual(payload["biggestCluster"] as? Int, 5)
    }

    func testAbsentOptionalsAreOmittedRatherThanSentAsNull() {
        let payload = WatchDashboardSnapshot.empty.messagePayload

        XCTAssertNil(payload["bestPartnerName"], "WCSession carries property-list types; NSNull is not one")
        XCTAssertNil(payload["bestPartnerSlot"])
    }

    // MARK: - Helpers

    private func session(stars: Int) -> SessionLog {
        SessionLog(
            id: UUID().uuidString,
            roomID: "room",
            userID: me,
            joinedAt: origin,
            leftAt: origin.addingTimeInterval(600),
            starsSpawned: stars
        )
    }

    private func event(_ partners: [String], from start: TimeInterval, to end: TimeInterval) -> SyncEvent {
        SyncEvent(
            id: UUID().uuidString,
            roomID: "room",
            userIDs: [me] + partners,
            startedAt: origin.addingTimeInterval(start),
            endedAt: origin.addingTimeInterval(end)
        )
    }
}
