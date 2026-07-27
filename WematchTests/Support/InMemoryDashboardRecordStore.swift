import Foundation
@testable import Wematch

/// In-memory `DashboardRecordStoring` for tests — never touches Application Support.
///
/// Without injecting this, every test that enters and leaves a room writes real records
/// into the test host's container: not hermetic, order-dependent, and it grows on every
/// run. Same reason `InMemoryKeychain` exists.
final class InMemoryDashboardRecordStore: DashboardRecordStoring, @unchecked Sendable {
    // Test-only: single-threaded XCTest access.
    private var stored = DashboardRecords.empty

    private(set) var appendCallCount = 0
    private(set) var deleteAllCallCount = 0

    /// Set to make the store fail, to check the caller does not treat persistence as
    /// something it can assume worked.
    var appendError: Error?

    init(seeded: DashboardRecords = .empty) {
        self.stored = seeded
    }

    func load() throws -> DashboardRecords {
        stored
    }

    func append(_ records: DashboardRecords) throws {
        appendCallCount += 1
        if let appendError { throw appendError }
        stored.merge(records)
    }

    func deleteAll() throws {
        deleteAllCallCount += 1
        stored = .empty
    }
}
