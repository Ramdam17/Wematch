import Foundation
@testable import Wematch

/// In-memory KeychainStoring for tests — never touches the real OS keychain,
/// so tests are hermetic and safe to run in parallel.
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
