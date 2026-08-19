import XCTest
import WematchCore
@testable import Wematch

/// The phone↔Watch wire (plan 1.10, H2).
///
/// What these replace is worth naming: every message used to be a `[String: Any]` read
/// with `as? Double ?? 0`, so a renamed key, a missing field or an unrecognised message
/// produced a plausible value rather than a failure — a heart at 0 BPM on the plot, or a
/// status the phone quietly never heard. The wire is now a closed type that either
/// decodes or throws, and these tests pin both halves of that.
final class WatchMessageTests: XCTestCase {

    // MARK: - Round trip

    /// Every case, so that adding one without a wire test fails here.
    private static let everyCase: [WatchMessage] = [
        .appLaunched,
        .enterRoom(roomID: "temp_alice_bob"),
        .exitRoom,
        .heartRate(bpm: 61, at: Date(timeIntervalSince1970: 1_780_000_000)),
        .heartRateStatus(.silent),
        .roomUpdate(
            WatchMessage.RoomUpdate(
                participants: [
                    .init(id: "alice", currentHR: 61, previousHR: 60, colorSlot: 3),
                    .init(id: "bob", currentHR: 64, previousHR: 66, colorSlot: 7)
                ],
                currentUserID: "alice",
                maxChain: 2,
                syncedCount: 2,
                newSyncFormations: true
            )
        ),
        .dashboardUpdate(
            WatchDashboardSnapshot(
                bestPartnerName: "bob",
                bestPartnerSlot: 7,
                starsMade: 12,
                connectedSeconds: 3_720,
                biggestCluster: 4
            )
        )
    ]

    func testEveryMessageSurvivesTheWire() throws {
        for message in Self.everyCase {
            let encoded = try message.encoded()
            let decoded = try WatchMessage.decoded(from: encoded)
            XCTAssertEqual(decoded, message, "\(message.logLabel) did not survive the round trip")
        }
    }

    func testTheEnvelopeCarriesAVersion() throws {
        let encoded = try WatchMessage.exitRoom.encoded()
        XCTAssertEqual(encoded["wematch.version"] as? Int, WatchMessage.wireVersion)
    }

    // MARK: - Rejection

    func testADictionaryFromSomewhereElseIsRefused() {
        XCTAssertThrowsError(try WatchMessage.decoded(from: ["type": "heartRateStatus", "status": "silent"])) { error in
            XCTAssertEqual(error as? WatchMessageError, .notAWematchMessage,
                           "the old hand-built shape must not be mistaken for a message")
        }
    }

    func testAMessageFromANewerBuildIsNamedRatherThanGuessedAt() throws {
        var encoded = try WatchMessage.exitRoom.encoded()
        encoded["wematch.version"] = WatchMessage.wireVersion + 1

        XCTAssertThrowsError(try WatchMessage.decoded(from: encoded)) { error in
            XCTAssertEqual(error as? WatchMessageError, .unsupportedVersion(WatchMessage.wireVersion + 1))
        }
    }

    func testGarbageInTheRightEnvelopeIsRefused() {
        let encoded: [String: Any] = [
            "wematch.version": WatchMessage.wireVersion,
            "wematch.payload": Data("not json".utf8)
        ]

        XCTAssertThrowsError(try WatchMessage.decoded(from: encoded)) { error in
            guard case .malformed = error as? WatchMessageError else {
                return XCTFail("expected a malformed payload, got \(error)")
            }
        }
    }

    // MARK: - Health data never reaches a log

    /// `String(describing:)` on this enum would put a BPM in the console the day someone
    /// logs the wrong case. Heart rate is health data (audit B5), so the label carries the
    /// case name and nothing else.
    func testNoLoggableLabelCarriesAHeartRate() {
        for message in Self.everyCase {
            let label = message.logLabel
            XCTAssertFalse(label.contains("61"), "\(label) leaks a heart rate")
            XCTAssertFalse(label.contains("64"), "\(label) leaks a heart rate")
        }
        XCTAssertEqual(WatchMessage.heartRate(bpm: 61, at: Date()).logLabel, "heartRate")
    }
}
