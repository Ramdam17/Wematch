import XCTest
@testable import Wematch

/// Pins the palette-slot mapping.
///
/// The slot decides which hue a user's heart is. Before this existed the assignment
/// went through `String.hashValue`, which Swift seeds randomly per process, so a user
/// drew a new colour on every launch and two devices never agreed. The expected values
/// below are the contract: if a future change to the hash makes them fail, everyone's
/// colour has silently moved.
///
/// `WatchHeartPalette.slot(forUserID:)` reimplements the same function for the Watch
/// target, which these tests cannot reach — keep the two in sync by hand.
final class HeartPaletteSlotTests: XCTestCase {

    // MARK: - Stability

    func testSlotIsStableForKnownUserIDs() {
        let expected: [(String, Int)] = [
            ("", 17),
            ("user_alpha", 1),
            ("cosmic_panda0042", 2),
            ("000123.abc", 7),
            ("000123_abc", 6),
            ("aVeryLongFirebaseUidLikeString0123456789", 10)
        ]

        for (userID, slot) in expected {
            XCTAssertEqual(
                HeartPaletteSlot(userID: userID).index, slot,
                "slot for '\(userID)' moved — every existing user's heart colour changes"
            )
        }
    }

    func testSlotIsIdenticalAcrossRepeatedDerivations() {
        let first = HeartPaletteSlot(userID: "uidA")
        let second = HeartPaletteSlot(userID: "uidA")
        XCTAssertEqual(first, second)
    }

    /// The mangled and unmangled forms of one Apple ID land on different slots, which is
    /// why the assignment is made from the firebaseSafe form throughout.
    func testMangledAndRawIDsDeriveDifferentSlots() {
        XCTAssertNotEqual(
            HeartPaletteSlot(userID: "000123.abc"),
            HeartPaletteSlot(userID: "000123_abc")
        )
    }

    // MARK: - Range

    func testIndexWrapsIntoPaletteRange() {
        XCTAssertEqual(HeartPaletteSlot(index: 0).index, 0)
        XCTAssertEqual(HeartPaletteSlot(index: 19).index, 19)
        XCTAssertEqual(HeartPaletteSlot(index: 20).index, 0)
        XCTAssertEqual(HeartPaletteSlot(index: 41).index, 1)
        XCTAssertEqual(HeartPaletteSlot(index: -1).index, 19)
        XCTAssertEqual(HeartPaletteSlot(index: -20).index, 0)
    }

    func testDerivedSlotsAlwaysLandInRange() {
        for i in 0..<500 {
            let index = HeartPaletteSlot(userID: "uid_\(i)").index
            XCTAssertTrue((0..<HeartPaletteSlot.count).contains(index))
        }
    }

    // MARK: - Palette

    func testPaletteCoversEverySlot() {
        XCTAssertEqual(WematchTheme.heartColors.count, HeartPaletteSlot.count)
        XCTAssertEqual(WematchTheme.heartColorHexes.count, HeartPaletteSlot.count)
    }

    func testEveryHueInThePaletteIsDistinct() {
        // A duplicated hex would silently merge two participants. Perceptual separation
        // is a stronger property and is checked by HeartPaletteSeparabilityTests; this
        // catches the crude case of a copy-paste.
        XCTAssertEqual(Set(WematchTheme.heartColorHexes).count, HeartPaletteSlot.count)
    }

    // MARK: - Firebase Round Trip

    func testFirebaseRoundTripPreservesSlot() throws {
        let participant = RoomParticipant(
            id: "uidA", username: "cosmic_panda0042",
            currentHR: 72, previousHR: 70,
            slot: HeartPaletteSlot(index: 13)
        )

        let decoded = try XCTUnwrap(
            RoomParticipant(id: "uidA", from: participant.firebaseDictionary)
        )
        XCTAssertEqual(decoded.slot.index, 13)
    }

    func testDecodingWithoutColorSlotDerivesItFromTheID() throws {
        let dictionary: [String: Any] = [
            "username": "cosmic_panda0042",
            "currentHR": 72.0,
            "previousHR": 70.0,
            "timestamp": 1_721_000_000.0
        ]

        let decoded = try XCTUnwrap(RoomParticipant(id: "000123_abc", from: dictionary))
        XCTAssertEqual(decoded.slot, HeartPaletteSlot(userID: "000123_abc"))
    }

    func testDecodingWrapsAnOutOfRangeColorSlot() throws {
        let dictionary: [String: Any] = [
            "username": "cosmic_panda0042",
            "currentHR": 72.0,
            "previousHR": 70.0,
            "colorSlot": 27,
            "timestamp": 1_721_000_000.0
        ]

        let decoded = try XCTUnwrap(RoomParticipant(id: "uidA", from: dictionary))
        XCTAssertEqual(decoded.slot.index, 7)
    }

    func testFirebaseDictionaryCarriesTheSlotAndNoColour() {
        let participant = RoomParticipant(
            id: "uidA", username: "cosmic_panda0042", slot: HeartPaletteSlot(index: 4)
        )
        let dictionary = participant.firebaseDictionary

        XCTAssertEqual(dictionary["colorSlot"] as? Int, 4)
        XCTAssertNil(dictionary["color"], "a resolved colour must not travel any more")
    }
}
