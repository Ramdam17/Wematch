import XCTest
@testable import Wematch

final class UsernameGeneratorTests: XCTestCase {

    private var generator: UsernameGenerator!

    override func setUp() {
        super.setUp()
        generator = UsernameGenerator()
    }

    func testGeneratesValidFormat() {
        let username = generator.generate()
        let pattern = #"^[a-z]+_[a-z]+\d{4}$"#
        XCTAssertNotNil(
            username.range(of: pattern, options: .regularExpression),
            "Username '\(username)' doesn't match expected format {adjective}_{animal}{NNNN}"
        )
    }

    func testNeverProducesEmptyComponents() {
        for _ in 0..<100 {
            let username = generator.generate()
            let parts = username.split(separator: "_")
            XCTAssertEqual(parts.count, 2, "Username should have exactly one underscore")
            XCTAssertFalse(parts[0].isEmpty, "Adjective should not be empty")
            XCTAssertFalse(parts[1].isEmpty, "Animal+number should not be empty")
        }
    }

    func testDictionariesHaveMinimumEntries() {
        XCTAssertGreaterThanOrEqual(generator.adjectiveCount, 100,
                                    "Should have at least 100 adjectives")
        XCTAssertGreaterThanOrEqual(generator.animalCount, 100,
                                    "Should have at least 100 animals")
    }

    func testGeneratesDifferentUsernames() {
        let usernames = (0..<100).map { _ in generator.generate() }
        let uniqueCount = Set(usernames).count
        XCTAssertGreaterThan(uniqueCount, 90,
                             "100 generations should produce mostly unique usernames, got \(uniqueCount)")
    }

    func testNumberIsFourDigitsZeroPadded() {
        for _ in 0..<50 {
            let username = generator.generate()
            let numberPart = String(username.suffix(4))
            XCTAssertNotNil(Int(numberPart),
                            "Last 4 characters '\(numberPart)' should be a number")
        }
    }
}
