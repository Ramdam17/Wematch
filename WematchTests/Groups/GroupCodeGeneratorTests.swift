import XCTest
@testable import Wematch

final class GroupCodeGeneratorTests: XCTestCase {

    func testCodeIsCorrectLength() {
        let code = GroupCodeGenerator.generate()
        XCTAssertEqual(code.count, 6, "Code should be 6 characters long")
    }

    func testCodeContainsOnlyAllowedCharacters() {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<100 {
            let code = GroupCodeGenerator.generate()
            let codeCharSet = CharacterSet(charactersIn: code)
            XCTAssertTrue(
                allowed.isSuperset(of: codeCharSet),
                "Code '\(code)' contains disallowed characters"
            )
        }
    }

    func testCodeExcludesConfusingCharacters() {
        // O, I, 0, 1 should never appear
        let confusing = CharacterSet(charactersIn: "OI01")
        for _ in 0..<200 {
            let code = GroupCodeGenerator.generate()
            let codeCharSet = CharacterSet(charactersIn: code)
            XCTAssertTrue(
                confusing.isDisjoint(with: codeCharSet),
                "Code '\(code)' contains confusing character (O, I, 0, or 1)"
            )
        }
    }

    func testGeneratesDifferentCodes() {
        let codes = (0..<100).map { _ in GroupCodeGenerator.generate() }
        let uniqueCount = Set(codes).count
        XCTAssertGreaterThan(uniqueCount, 90,
                             "100 codes should produce mostly unique values, got \(uniqueCount)")
    }
}
