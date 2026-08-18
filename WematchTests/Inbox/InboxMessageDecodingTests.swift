import XCTest
@testable import Wematch

/// Plan 1.7 (audit D3). A message whose `type` this build does not know used to be
/// dropped on the floor by the repository's `compactMap` — the user was never told
/// anything arrived. It now decodes to `.unknown`, keeping what the server sent.
final class InboxMessageDecodingTests: XCTestCase {

    private let sentAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func message(type: String?) -> InboxMessage? {
        var data: [String: Any] = ["payload": ["username": "cosmic_panda0042"], "isRead": false]
        if let type { data["type"] = type }
        return InboxMessage(id: "msg1", recipientID: "uid1", data: data, createdAt: sentAt)
    }

    // MARK: - Unknown types survive

    func testAMessageOfAnUnknownTypeIsKeptRatherThanDropped() {
        XCTAssertNotNil(message(type: "roomHeartbeatShared"),
                        "a type this build predates is still a message the user received")
    }

    func testAnUnknownTypeRemembersWhatTheServerSent() {
        XCTAssertEqual(message(type: "roomHeartbeatShared")?.type, .unknown("roomHeartbeatShared"))
    }

    func testAnUnknownTypeRoundTripsThroughItsRawValue() {
        XCTAssertEqual(InboxMessageType.unknown("roomHeartbeatShared").rawValue, "roomHeartbeatShared")
    }

    func testAnUnknownMessageOffersNoActions() {
        XCTAssertFalse(InboxMessageType.unknown("roomHeartbeatShared").hasActions,
                       "we cannot offer a button for a message we cannot interpret")
    }

    // MARK: - Known types keep decoding

    func testEveryKnownTypeStillDecodesToItself() {
        for known in InboxMessageType.knownCases {
            XCTAssertEqual(message(type: known.rawValue)?.type, known)
        }
    }

    func testKnownTypesAreNeverReportedAsUnknown() {
        for known in InboxMessageType.knownCases {
            XCTAssertFalse(known.isUnknown, "\(known.rawValue) is a type this build handles")
        }
    }

    // MARK: - Malformed documents

    func testADocumentWithNoTypeAtAllIsRejected() {
        XCTAssertNil(message(type: nil),
                     "a document with no type field is malformed, not a message from the future")
    }

    func testDecodingCarriesThePayloadAndTheDate() {
        let decoded = message(type: "friendRequest")
        XCTAssertEqual(decoded?.payload["username"], "cosmic_panda0042")
        XCTAssertEqual(decoded?.createdAt, sentAt)
        XCTAssertEqual(decoded?.isRead, false)
    }
}
