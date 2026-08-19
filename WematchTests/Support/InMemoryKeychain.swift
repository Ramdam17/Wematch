import Foundation
@testable import Wematch

/// In-memory KeychainStoring for tests — never touches the real OS keychain,
/// so tests are hermetic and safe to run in parallel.
/// `@unchecked Sendable` justification: test-only. The stored state is written and
/// read from the main actor inside a single test method, and no instance outlives
/// the test that made it (plan 1.10).
final class InMemoryKeychain: KeychainStoring, @unchecked Sendable {
    // Test-only: single-threaded XCTest access.
    private var storage: [String: String] = [:]

    func save(key: String, value: String) throws {
        storage[key] = value
    }

    func retrieve(key: String) -> String? {
        storage[key]
    }

    func delete(key: String) throws {
        storage[key] = nil
    }
}
