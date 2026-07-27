import XCTest
@testable import Wematch

/// Pins the dashboard metrics, and in particular the difference between summing sync
/// durations and taking their union.
///
/// The union is the one the Watch shows as "Time in sync". Getting it wrong is not a
/// rounding error: a minute inside a five-way cluster is ten pairwise events, so the sum
/// reports ten minutes of connection for one minute lived — and can exceed the total time
/// the user spent in rooms at all.
final class DashboardMetricsTests: XCTestCase {

    private let origin = Date(timeIntervalSince1970: 1_000_000)
    private let me = "me"

    // MARK: - Union vs sum

    func testOverlappingSyncsCountOnceTowardConnectedTime() {
        // Three partners, all synced with me over the same single minute.
        let events = [
            makeEvent(["a"], from: 0, to: 60),
            makeEvent(["b"], from: 0, to: 60),
            makeEvent(["c"], from: 0, to: 60)
        ]

        let metrics = compute(syncEvents: events)

        XCTAssertEqual(metrics.connectedDuration, 60, "one minute lived is one minute connected")
        XCTAssertEqual(metrics.totalSyncDuration, 180, "the sum still answers its own question")
    }

    func testPartiallyOverlappingSyncsMergeIntoOneStretch() {
        let events = [
            makeEvent(["a"], from: 0, to: 100),
            makeEvent(["b"], from: 60, to: 200)
        ]

        XCTAssertEqual(compute(syncEvents: events).connectedDuration, 200)
    }

    func testDisjointSyncsAddUp() {
        let events = [
            makeEvent(["a"], from: 0, to: 60),
            makeEvent(["b"], from: 300, to: 360)
        ]

        XCTAssertEqual(compute(syncEvents: events).connectedDuration, 120)
    }

    /// Ranges that meet end-to-start are one uninterrupted stretch, not two — the user
    /// never stopped being connected.
    func testTouchingSyncsAreOneStretch() {
        let events = [
            makeEvent(["a"], from: 0, to: 60),
            makeEvent(["b"], from: 60, to: 120)
        ]

        XCTAssertEqual(compute(syncEvents: events).connectedDuration, 120)
    }

    func testAnEventFullyInsideAnotherAddsNothing() {
        let events = [
            makeEvent(["a"], from: 0, to: 600),
            makeEvent(["b"], from: 100, to: 200)
        ]

        XCTAssertEqual(compute(syncEvents: events).connectedDuration, 600)
    }

    func testConnectedTimeNeverExceedsTimeSpentInRooms() {
        let sessions = [makeSession(from: 0, to: 600)]
        let events = (0..<10).map { index in makeEvent(["p\(index)"], from: 0, to: 600) }

        let metrics = DashboardMetrics.compute(
            from: sessions, syncEvents: events, userID: me, asOf: origin
        )

        XCTAssertLessThanOrEqual(metrics.connectedDuration, metrics.totalSessionDuration)
        XCTAssertGreaterThan(
            metrics.totalSyncDuration, metrics.totalSessionDuration,
            "the sum is expected to overshoot — that is precisely why it is not the headline"
        )
    }

    // MARK: - Ongoing syncs

    func testAnOngoingSyncCountsUpToTheReferenceInstant() {
        let events = [makeOngoingEvent(["a"], from: 0)]

        let metrics = DashboardMetrics.compute(
            from: [], syncEvents: events, userID: me, asOf: origin.addingTimeInterval(90)
        )

        XCTAssertEqual(metrics.connectedDuration, 90)
        XCTAssertEqual(metrics.totalSyncDuration, 0, "SyncEvent.duration still reports 0 while open")
    }

    func testAZeroLengthEventContributesNothing() {
        XCTAssertEqual(compute(syncEvents: [makeEvent(["a"], from: 50, to: 50)]).connectedDuration, 0)
    }

    func testNoEventsIsZeroNotACrash() {
        let metrics = compute(syncEvents: [])

        XCTAssertEqual(metrics.connectedDuration, 0)
        XCTAssertEqual(metrics.maxClusterSize, 0)
        XCTAssertNil(metrics.bestPartner)
    }

    // MARK: - Best partner

    func testBestPartnerIsTheOneWithTheMostSharedTime() {
        let events = [
            makeEvent(["a"], from: 0, to: 100),
            makeEvent(["b"], from: 200, to: 500),
            makeEvent(["a"], from: 600, to: 650)
        ]

        let best = compute(syncEvents: events).bestPartner

        XCTAssertEqual(best?.userID, "b")
        XCTAssertEqual(best?.duration, 300)
    }

    /// Same reason the headline is a union: two overlapping cluster events that both
    /// include the same person are one stretch spent with them.
    func testAPartnersOverlappingEventsAreNotDoubleCounted() {
        let events = [
            makeEvent(["a", "b"], from: 0, to: 100),
            makeEvent(["a", "c"], from: 50, to: 150)
        ]

        let best = compute(syncEvents: events).bestPartner

        XCTAssertEqual(best?.userID, "a")
        XCTAssertEqual(best?.duration, 150, "a was present for one 150s stretch, not 200s")
    }

    func testTiesBreakDeterministically() {
        let events = [
            makeEvent(["zoe"], from: 0, to: 100),
            makeEvent(["amy"], from: 200, to: 300)
        ]

        // Equal totals must not depend on dictionary ordering, or the Watch would name a
        // different "best friend" on every refresh.
        for _ in 0..<20 {
            XCTAssertEqual(compute(syncEvents: events).bestPartner?.userID, "amy")
        }
    }

    func testTheUserIsNeverTheirOwnBestPartner() {
        let events = [makeEvent([], from: 0, to: 100)]

        XCTAssertNil(
            compute(syncEvents: events).bestPartner,
            "an event listing only the user has no partner in it"
        )
    }

    // MARK: - Biggest cluster

    func testMaxClusterSizeCountsTheWholeClusterIncludingTheUser() {
        let events = [
            makeEvent(["a"], from: 0, to: 10),
            makeEvent(["a", "b", "c", "d"], from: 20, to: 30)
        ]

        XCTAssertEqual(compute(syncEvents: events).maxClusterSize, 5)
    }

    func testARepeatedIDDoesNotInflateTheCluster() {
        let events = [makeEvent(["a", "a", "b"], from: 0, to: 10)]

        XCTAssertEqual(compute(syncEvents: events).maxClusterSize, 3)
    }

    // MARK: - Helpers

    private func compute(syncEvents: [SyncEvent]) -> DashboardMetrics {
        DashboardMetrics.compute(from: [], syncEvents: syncEvents, userID: me, asOf: origin)
    }

    private func makeEvent(
        _ partners: [String],
        from start: TimeInterval,
        to end: TimeInterval
    ) -> SyncEvent {
        SyncEvent(
            id: "\(partners.joined(separator: "-"))-\(start)-\(end)",
            roomID: "room",
            userIDs: [me] + partners,
            startedAt: origin.addingTimeInterval(start),
            endedAt: origin.addingTimeInterval(end)
        )
    }

    private func makeOngoingEvent(_ partners: [String], from start: TimeInterval) -> SyncEvent {
        SyncEvent(
            id: "ongoing-\(start)",
            roomID: "room",
            userIDs: [me] + partners,
            startedAt: origin.addingTimeInterval(start),
            endedAt: nil
        )
    }

    private func makeSession(from start: TimeInterval, to end: TimeInterval) -> SessionLog {
        SessionLog(
            id: "session-\(start)",
            roomID: "room",
            userID: me,
            joinedAt: origin.addingTimeInterval(start),
            leftAt: origin.addingTimeInterval(end)
        )
    }
}
