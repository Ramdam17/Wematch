import Foundation
import OSLog

/// Where the dashboard's raw records live.
protocol DashboardRecordStoring: Sendable {
    func load() throws -> DashboardRecords
    /// Folds a batch into what is already stored.
    func append(_ records: DashboardRecords) throws
    func deleteAll() throws
}

/// On-device JSON store, in Application Support.
///
/// Local rather than Firestore or CloudKit on purpose: this is personal history that no
/// other client needs, and keeping it off the network means it never becomes a rule to
/// write or a record to share. Plan 1.2 parked CloudKit for "later personal-data features
/// (dashboards, v2)" — this keeps that door open instead of walking through it early.
///
/// Application Support rather than Caches (the system may evict Caches, and a lifetime
/// total that silently resets is worse than no total) and rather than Documents (not the
/// user's own files, and it would show up in Files.app).
struct DashboardRecordStore: DashboardRecordStoring {

    /// The only stored state, so the type stays `Sendable` — `FileManager` is not, even
    /// though the calls made through it here are safe.
    private let fileURL: URL

    init(fileName: String = "dashboard-records.json") {
        let fileManager = FileManager.default

        let directory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        self.fileURL = directory.appendingPathComponent(fileName)
    }

    /// Testing seam: point the store at a directory the test owns.
    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("dashboard-records.json")
    }

    func load() throws -> DashboardRecords {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }

        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode(DashboardRecords.self, from: data)
    }

    func append(_ records: DashboardRecords) throws {
        guard !records.isEmpty || !records.displayNames.isEmpty else { return }

        var stored = try load()
        stored.merge(records)
        try write(stored)
    }

    func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
        Log.settings.info("Dashboard records erased")
    }

    // MARK: - Private

    private func write(_ records: DashboardRecords) throws {
        let data = try Self.encoder.encode(records)

        // Encrypted at rest while the device is locked. These records name the people the
        // user syncs with, which is exactly the kind of thing that should not be readable
        // from a lifted, locked phone.
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
