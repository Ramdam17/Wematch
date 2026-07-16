import XCTest
@testable import Wematch

final class FirebaseSafeTests: XCTestCase {

    func testReplacesDotsWithUnderscores() {
        XCTAssertEqual("000123.abc.def".firebaseSafe(), "000123_abc_def")
    }

    func testNoOpForAlreadySafeStrings() {
        XCTAssertEqual("alice_bob".firebaseSafe(), "alice_bob")
    }

    func testIsIdempotent() {
        let once = "a.b.c".firebaseSafe()
        XCTAssertEqual(once.firebaseSafe(), once)
    }

    /// The mangling is NOT invertible: distinct raw IDs can collide after
    /// sanitization, and the original cannot be recovered. This is why business
    /// logic must never parse raw IDs back out of firebaseSafe path keys
    /// (audit finding E1).
    func testManglingIsLossy() {
        XCTAssertEqual("a.b".firebaseSafe(), "a_b".firebaseSafe())
    }
}
