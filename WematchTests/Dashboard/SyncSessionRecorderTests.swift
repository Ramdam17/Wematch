import XCTest
@testable import Wematch

/// Pins what a room session turns into on disk.
///
/// The subtle part is that a cluster changing shape must not read as a break in being
/// connected. The recorder closes one event and opens the next at the same instant, and
/// `DashboardMetrics` merges touching intervals — the last test here checks the two
/// halves actually agree, since either alone can look correct while the pair is wrong.
final class SyncSessionRecorderTests: XCTestCase {

    private let origin = Date(timeIntervalSince1970: 2_000_000)
    private let me = "me"

    // MARK: - Events

    func testAClusterProducesOneEventCoveringItsLifetime() {
        var recorder = makeRecorder()

        recorder.observe(cluster: [me, "a"], at: at(0))
        recorder.observe(cluster: [], at: at(100))
        let records = recorder.finish(at: at(150))

        XCTAssertEqual(records.syncEvents.count, 1)
        XCTAssertEqual(records.syncEvents.first?.userIDs, ["a", me].sorted())
        XCTAssertEqual(records.syncEvents.first?.duration, 100)
    }

    func testBeingAloneRecordsNothing() {
        var recorder = makeRecorder()

        recorder.observe(cluster: [me], at: at(0))
        recorder.observe(cluster: [], at: at(50))
        let records = recorder.finish(at: at(100))

        XCTAssertTrue(records.syncEvents.isEmpty, "a cluster of one is not a sync")
    }

    func testAMembershipChangeSplitsTheEventWithoutLeavingAGap() {
        var recorder = makeRecorder()

        recorder.observe(cluster: [me, "a"], at: at(0))
        recorder.observe(cluster: [me, "a", "b"], at: at(60))
        let records = recorder.finish(at: at(120))

        XCTAssertEqual(records.syncEvents.count, 2)
        XCTAssertEqual(records.syncEvents[0].endedAt, records.syncEvents[1].startedAt,
                       "the two events must touch — the user never stopped being connected")
        XCTAssertEqual(records.syncEvents[1].userIDs, ["a", "b", me].sorted())
    }

    func testRepeatedIdenticalObservationsDoNotSplitTheEvent() {
        var recorder = makeRecorder()

        // The room ticks constantly; an unchanged cluster must not shatter into
        // one event per tick.
        for second in stride(from: 0, through: 100, by: 10) {
            recorder.observe(cluster: [me, "a"], at: at(TimeInterval(second)))
        }
        let records = recorder.finish(at: at(100))

        XCTAssertEqual(records.syncEvents.count, 1)
        XCTAssertEqual(records.syncEvents.first?.duration, 100)
    }

    func testFinishClosesAnEventStillOpen() {
        var recorder = makeRecorder()

        recorder.observe(cluster: [me, "a"], at: at(0))
        let records = recorder.finish(at: at(75))

        XCTAssertEqual(records.syncEvents.count, 1)
        XCTAssertEqual(records.syncEvents.first?.endedAt, at(75))
    }

    func testAClusterThatFormsAndDissolvesInTheSameInstantIsDropped() {
        var recorder = makeRecorder()

        recorder.observe(cluster: [me, "a"], at: at(40))
        recorder.observe(cluster: [], at: at(40))
        let records = recorder.finish(at: at(90))

        XCTAssertTrue(records.syncEvents.isEmpty, "a zero-length event only dilutes averages")
    }

    // MARK: - Session

    func testStarsAccumulateOnTheSession() {
        var recorder = makeRecorder()

        recorder.recordStars(3)
        recorder.recordStars(0)
        recorder.recordStars(2)
        let records = recorder.finish(at: at(10))

        XCTAssertEqual(records.sessions.first?.starsSpawned, 5)
    }

    func testTheSessionSpansJoinToLeave() {
        var recorder = makeRecorder()

        let records = recorder.finish(at: at(600))

        XCTAssertEqual(records.sessions.count, 1)
        XCTAssertEqual(records.sessions.first?.joinedAt, origin)
        XCTAssertEqual(records.sessions.first?.duration, 600)
    }

    // MARK: - Display names

    func testDisplayNamesSkipTheUserAndEmptyNames() {
        var recorder = makeRecorder()

        recorder.noteDisplayNames([me: "myself", "a": "brave_otter", "b": ""])
        let records = recorder.finish(at: at(10))

        XCTAssertEqual(records.displayNames, ["a": "brave_otter"])
    }

    // MARK: - Agreement with the metrics

    /// The recorder and the metrics have to be right *together*: splitting a stretch into
    /// touching events is only safe because the union merges them back.
    func testASplitClusterStillCountsAsOneUnbrokenStretch() {
        var recorder = makeRecorder()

        recorder.observe(cluster: [me, "a"], at: at(0))
        recorder.observe(cluster: [me, "a", "b"], at: at(60))
        recorder.observe(cluster: [me, "b"], at: at(120))
        recorder.observe(cluster: [], at: at(180))
        let records = recorder.finish(at: at(200))

        XCTAssertEqual(records.syncEvents.count, 3, "three shapes")

        let metrics = DashboardMetrics.compute(
            from: records.sessions,
            syncEvents: records.syncEvents,
            userID: me,
            asOf: at(200)
        )

        XCTAssertEqual(metrics.connectedDuration, 180, "but one unbroken stretch of being connected")
        XCTAssertEqual(metrics.maxClusterSize, 3)
        XCTAssertEqual(metrics.bestPartner?.userID, "a")
        XCTAssertEqual(metrics.bestPartner?.duration, 120)
    }

    // MARK: - Helpers

    private func makeRecorder() -> SyncSessionRecorder {
        var counter = 0
        return SyncSessionRecorder(
            sessionID: "session",
            roomID: "room",
            userID: me,
            startedAt: origin,
            makeEventID: {
                counter += 1
                return "event-\(counter)"
            }
        )
    }

    private func at(_ offset: TimeInterval) -> Date {
        origin.addingTimeInterval(offset)
    }
}
