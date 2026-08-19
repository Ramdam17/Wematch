import XCTest
import WematchCore
@testable import Wematch

/// Plan 1.7 (audit D1–D3). Three independent things can go wrong in a room, and until
/// now all three produced the same picture: a plot that looks like a quiet room.
/// `RoomConnectionState` folds them into the one thing the user is shown, worst first.
final class RoomConnectionStateTests: XCTestCase {

    private func resolve(offline: Bool = false,
                         room: Bool = false,
                         watchUnreachable: Bool = false,
                         heartRate: WatchHeartRateStatus = .streaming,
                         sharing: Bool = true) -> RoomConnectionState {
        RoomConnectionState.resolve(isOffline: offline,
                                    roomUnreachable: room,
                                    watchUnreachable: watchUnreachable,
                                    watchHeartRate: heartRate,
                                    isSharingHeartRate: sharing)
    }

    // MARK: - Nothing wrong

    func testEverythingWorkingIsConnected() {
        XCTAssertEqual(resolve(), .connected)
    }

    func testAWatchStillWarmingUpIsNotAFailure() {
        XCTAssertEqual(resolve(heartRate: .waitingForFirstSample), .connected,
                       "the first sample takes seconds — that is not a fault to announce")
    }

    func testConnectedSaysNothing() {
        XCTAssertNil(RoomConnectionState.connected.message)
        XCTAssertFalse(RoomConnectionState.connected.needsAttention)
    }

    // MARK: - Each fault on its own

    /// The case the `withCancel` handler cannot see: airplane mode does not cancel a
    /// Realtime Database listener, it just stops feeding it (field-test case S8).
    func testLosingTheNetworkIsReported() {
        XCTAssertEqual(resolve(offline: true), .offline)
    }

    func testADeadRoomStreamIsReported() {
        XCTAssertEqual(resolve(room: true), .roomUnreachable)
    }

    func testAnUnreachableWatchIsReported() {
        XCTAssertEqual(resolve(watchUnreachable: true), .watchUnreachable)
    }

    func testASilentHeartRateFeedIsReported() {
        XCTAssertEqual(resolve(heartRate: .silent), .heartRateUnavailable(.silent))
    }

    func testAStoppedHeartRateFeedIsReported() {
        XCTAssertEqual(resolve(heartRate: .stopped), .heartRateUnavailable(.stopped))
    }

    func testFailingToShareOurOwnHeartIsReported() {
        XCTAssertEqual(resolve(sharing: false), .notSharing)
    }

    // MARK: - Worst wins (the point of folding them into one)

    func testBeingOfflineOutranksEverythingElse() {
        XCTAssertEqual(resolve(offline: true, room: true, watchUnreachable: true,
                               heartRate: .silent, sharing: false),
                       .offline,
                       "every other fault is downstream of having no network")
    }

    func testADeadRoomStreamOutranksEverythingBelowIt() {
        XCTAssertEqual(resolve(room: true, watchUnreachable: true, heartRate: .silent, sharing: false),
                       .roomUnreachable,
                       "seeing nobody is worse than not being seen")
    }

    func testAnUnreachableWatchOutranksItsOwnSilentFeed() {
        XCTAssertEqual(resolve(watchUnreachable: true, heartRate: .silent), .watchUnreachable,
                       "no Watch is the cause; a silent feed is the symptom")
    }

    func testASilentFeedOutranksAFailedWrite() {
        XCTAssertEqual(resolve(heartRate: .silent, sharing: false), .heartRateUnavailable(.silent),
                       "with no heart to send, the failed write is a consequence")
    }

    // MARK: - Every fault says something, and says which are serious

    func testEveryFaultCarriesAMessageAndAsksForAttention() {
        let faults: [RoomConnectionState] = [
            .offline, .roomUnreachable, .watchUnreachable, .heartRateUnavailable(.silent),
            .heartRateUnavailable(.stopped), .notSharing
        ]
        for fault in faults {
            XCTAssertTrue(fault.needsAttention, "\(fault) is a fault")
            XCTAssertFalse(fault.message?.isEmpty ?? true, "\(fault) must say something")
        }
    }

    func testTheStatesThatMakeThePlotALieAreCritical() {
        XCTAssertTrue(RoomConnectionState.roomUnreachable.isCritical,
                      "a plot showing stale hearts is a lie, not a warning")
        XCTAssertTrue(RoomConnectionState.offline.isCritical)
        XCTAssertFalse(RoomConnectionState.watchUnreachable.isCritical)
        XCTAssertFalse(RoomConnectionState.notSharing.isCritical)
        XCTAssertFalse(RoomConnectionState.heartRateUnavailable(.silent).isCritical)
    }

    /// Was "one wording for one fact, wherever it is shown" — which put the Watch's
    /// three-line instruction on top of the phone's plot. The fact is one; the sentence
    /// is written for the device that shows it.
    func testTheSilentFeedMessageIsThePhonesOwnWording() {
        XCTAssertEqual(RoomConnectionState.heartRateUnavailable(.silent).message,
                       WatchHeartRateStatus.silent.phoneSummary)
        XCTAssertNotEqual(RoomConnectionState.heartRateUnavailable(.silent).message,
                          WatchHeartRateStatus.silent.watchExplanation)
    }
}
