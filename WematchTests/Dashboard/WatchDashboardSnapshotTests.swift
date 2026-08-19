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
    //
    // These used to assert on a hand-built `[String: Any]` and on optionals being omitted
    // from it, because WCSession carries property-list types and `NSNull` is not one. The
    // snapshot now crosses inside a `WatchMessage`, encoded once (plan 1.10) — so the
    // question is no longer which keys were written, it is whether the value the Watch
    // decodes is the value the phone computed.

    func testTheSnapshotSurvivesTheWireUnchanged() throws {
        let snapshot = WatchDashboardSnapshot(
            bestPartnerName: "brave_otter",
            bestPartnerSlot: 7,
            starsMade: 128,
            connectedSeconds: 13_320,
            biggestCluster: 5
        )

        let encoded = try WatchMessage.dashboardUpdate(snapshot).encoded()
        guard case .dashboardUpdate(let decoded) = try WatchMessage.decoded(from: encoded) else {
            return XCTFail("a dashboard update decoded as something else")
        }

        XCTAssertEqual(decoded, snapshot)
    }

    func testAnEmptySnapshotSurvivesTheWireToo() throws {
        let encoded = try WatchMessage.dashboardUpdate(.empty).encoded()
        guard case .dashboardUpdate(let decoded) = try WatchMessage.decoded(from: encoded) else {
            return XCTFail("a dashboard update decoded as something else")
        }

        XCTAssertEqual(decoded, .empty)
        XCTAssertNil(decoded.bestPartnerName, "an absent partner must stay absent, not become a name")
        XCTAssertNil(decoded.bestPartnerSlot)
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
