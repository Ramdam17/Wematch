import CloudKit
import OSLog

final class CloudKitUserProfileRepository: UserProfileRepository {

    private let database: CKDatabase

    init(database: CKDatabase = CloudKitManager.shared.container.publicCloudDatabase) {
        self.database = database
    }

    func fetchProfile(userID: String) async throws -> UserProfile? {
        let recordID = CKRecord.ID(recordName: userID)
        do {
            let record = try await database.record(for: recordID)
            Log.cloudKit.debug("Fetched UserProfile for \(userID)")
            return Self.userProfile(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            Log.cloudKit.debug("No UserProfile found for \(userID)")
            return nil
        }
    }

    func createProfile(_ profile: UserProfile) async throws {
        let record = Self.record(from: profile)
        try await database.save(record)
        Log.cloudKit.info("Created UserProfile for \(profile.id) with username '\(profile.username)'")
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let predicate = NSPredicate(format: "username == %@", username)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        let (results, _) = try await database.records(matching: query, resultsLimit: 1)
        let isAvailable = results.isEmpty
        Log.cloudKit.debug("Username '\(username)' available: \(isAvailable)")
        return isAvailable
    }

    // MARK: - Record Conversion

    private static func userProfile(from record: CKRecord) -> UserProfile {
        UserProfile(
            id: record.recordID.recordName,
            username: record["username"] as? String ?? "",
            displayName: record["displayName"] as? String,
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date(),
            usernameEdited: (record["usernameEdited"] as? Int64 ?? 0) != 0
        )
    }

    private static func record(from profile: UserProfile) -> CKRecord {
        let recordID = CKRecord.ID(recordName: profile.id)
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)
        record["username"] = profile.username as CKRecordValue
        record["displayName"] = profile.displayName as CKRecordValue?
        record["createdAt"] = profile.createdAt as CKRecordValue
        record["usernameEdited"] = (profile.usernameEdited ? 1 : 0) as CKRecordValue
        return record
    }
}
