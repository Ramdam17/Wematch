import CloudKit
import OSLog

protocol InboxMessageRepository: Sendable {
    func createMessage(recipientID: String, type: InboxMessageType, payload: [String: String]) async throws
}

final class CloudKitInboxMessageRepository: InboxMessageRepository {

    private let database: CKDatabase

    init(database: CKDatabase = CloudKitManager.shared.container.publicCloudDatabase) {
        self.database = database
    }

    func createMessage(recipientID: String, type: InboxMessageType, payload: [String: String]) async throws {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "InboxMessage", recordID: recordID)
        record["recipientID"] = recipientID as CKRecordValue
        record["type"] = type.rawValue as CKRecordValue
        let payloadData = try JSONEncoder().encode(payload)
        record["payload"] = payloadData as CKRecordValue
        record["isRead"] = 0 as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        try await database.save(record)
        Log.groups.info("Created inbox message type=\(type.rawValue) for user \(recipientID)")
    }
}
