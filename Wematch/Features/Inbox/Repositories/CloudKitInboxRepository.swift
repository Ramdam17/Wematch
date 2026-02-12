import CloudKit
import OSLog

final class CloudKitInboxRepository: InboxRepository {

    private let database: CKDatabase

    init(database: CKDatabase = CloudKitManager.shared.publicDatabase) {
        self.database = database
    }

    // MARK: - Fetch

    func fetchMessages(userID: String) async throws -> [InboxMessage] {
        let predicate = NSPredicate(format: "recipientID == %@", userID)
        let query = CKQuery(recordType: "InboxMessage", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query)
            let messages = results.compactMap { _, result in
                try? result.get()
            }.compactMap(Self.inboxMessage(from:))

            Log.inbox.debug("Fetched \(messages.count) inbox messages for user \(userID)")
            return messages
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
    }

    // MARK: - Read Status

    func markAsRead(messageID: String) async throws {
        let recordID = CKRecord.ID(recordName: messageID)
        let record = try await database.record(for: recordID)
        record["isRead"] = 1 as CKRecordValue
        try await database.save(record)
        Log.inbox.debug("Marked message \(messageID) as read")
    }

    func markAllAsRead(userID: String) async throws {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "recipientID == %@", userID),
            NSPredicate(format: "isRead == %d", 0)
        ])
        let query = CKQuery(recordType: "InboxMessage", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query)
            let records = results.compactMap { _, result in try? result.get() }
            guard !records.isEmpty else { return }

            for record in records {
                record["isRead"] = 1 as CKRecordValue
            }

            _ = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .changedKeys)

            Log.inbox.info("Marked \(records.count) messages as read for user \(userID)")
        } catch let error as CKError where error.code == .unknownItem {
            return // No messages yet
        }
    }

    // MARK: - Delete

    func deleteMessage(messageID: String) async throws {
        let recordID = CKRecord.ID(recordName: messageID)
        try await database.deleteRecord(withID: recordID)
        Log.inbox.info("Deleted inbox message \(messageID)")
    }

    // MARK: - Unread Count

    func unreadCount(userID: String) async throws -> Int {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "recipientID == %@", userID),
            NSPredicate(format: "isRead == %d", 0)
        ])
        let query = CKQuery(recordType: "InboxMessage", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query)
            return results.count
        } catch let error as CKError where error.code == .unknownItem {
            return 0
        }
    }

    // MARK: - Record Conversion

    private static func inboxMessage(from record: CKRecord) -> InboxMessage? {
        guard let typeRaw = record["type"] as? String,
              let type = InboxMessageType(rawValue: typeRaw) else {
            Log.inbox.warning("Unknown inbox message type in record \(record.recordID.recordName)")
            return nil
        }

        let payload: [String: String]
        if let data = record["payload"] as? Data,
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            payload = decoded
        } else {
            payload = [:]
        }

        return InboxMessage(
            id: record.recordID.recordName,
            recipientID: record["recipientID"] as? String ?? "",
            type: type,
            payload: payload,
            isRead: (record["isRead"] as? Int64 ?? 0) != 0,
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date()
        )
    }
}
