import CloudKit
import OSLog

final class CloudKitGroupRepository: GroupRepository {

    private let database: CKDatabase

    init(database: CKDatabase = CloudKitManager.shared.publicDatabase) {
        self.database = database
    }

    // MARK: - Groups

    func fetchMyGroups(userID: String) async throws -> [Group] {
        // CloudKit doesn't support OR predicates — run two queries and merge
        async let adminResults = fetchGroups(predicate: NSPredicate(format: "adminID == %@", userID))
        async let memberResults = fetchGroups(predicate: NSPredicate(format: "memberIDs CONTAINS %@", userID))

        let allGroups = try await adminResults + memberResults
        // Deduplicate (user could theoretically appear in both)
        var seen = Set<String>()
        let unique = allGroups.filter { seen.insert($0.id).inserted }

        Log.groups.debug("Fetched \(unique.count) groups for user \(userID)")
        return unique.sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchGroups(predicate: NSPredicate) async throws -> [Group] {
        let query = CKQuery(recordType: "Group", predicate: predicate)
        do {
            let (results, _) = try await database.records(matching: query)
            return results.compactMap { _, result in try? result.get() }.map(Self.group(from:))
        } catch let error as CKError where error.code == .unknownItem {
            return [] // Record type not yet in schema
        }
    }

    func createGroup(name: String, adminID: String) async throws -> Group {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupError.emptyName }

        let code = try await generateUniqueCode()
        let group = Group(
            id: UUID().uuidString,
            name: trimmedName,
            code: code,
            adminID: adminID,
            memberIDs: [],
            createdAt: Date()
        )

        let record = Self.record(from: group)
        try await database.save(record)
        Log.groups.info("Created group '\(trimmedName)' with code \(code)")
        return group
    }

    func deleteGroup(groupID: String) async throws {
        let recordID = CKRecord.ID(recordName: groupID)
        try await database.deleteRecord(withID: recordID)

        // Also delete all join requests for this group
        let predicate = NSPredicate(format: "groupID == %@", groupID)
        let query = CKQuery(recordType: "JoinRequest", predicate: predicate)
        let (results, _) = try await database.records(matching: query)
        for (id, _) in results {
            try await database.deleteRecord(withID: id)
        }

        Log.groups.info("Deleted group \(groupID) and its join requests")
    }

    func searchGroups(query searchText: String) async throws -> [Group] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let predicate = NSPredicate(format: "name BEGINSWITH[c] %@", trimmed)
        let query = CKQuery(recordType: "Group", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let (results, _) = try await database.records(matching: query)
        let groups = results.compactMap { _, result in
            try? result.get()
        }.map(Self.group(from:))

        Log.groups.debug("Search '\(trimmed)' returned \(groups.count) groups")
        return groups
    }

    func fetchGroup(byCode code: String) async throws -> Group? {
        let predicate = NSPredicate(format: "code == %@", code.uppercased())
        let query = CKQuery(recordType: "Group", predicate: predicate)
        let (results, _) = try await database.records(matching: query, resultsLimit: 1)

        guard let (_, result) = results.first,
              let record = try? result.get() else {
            return nil
        }

        return Self.group(from: record)
    }

    // MARK: - Join Requests

    func sendJoinRequest(groupID: String, userID: String, username: String) async throws {
        // Fetch the group to validate
        let groupRecordID = CKRecord.ID(recordName: groupID)
        let groupRecord: CKRecord
        do {
            groupRecord = try await database.record(for: groupRecordID)
        } catch {
            throw GroupError.groupNotFound
        }

        let group = Self.group(from: groupRecord)

        // Check member cap
        guard group.memberIDs.count < 20 else { throw GroupError.groupFull }

        // Check if already admin or member
        guard group.adminID != userID && !group.memberIDs.contains(userID) else {
            throw GroupError.alreadyMember
        }

        // Check for existing pending request
        let pendingPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "groupID == %@", groupID),
            NSPredicate(format: "userID == %@", userID),
            NSPredicate(format: "status == %@", JoinRequestStatus.pending.rawValue)
        ])
        let pendingQuery = CKQuery(recordType: "JoinRequest", predicate: pendingPredicate)
        let (existing, _) = try await database.records(matching: pendingQuery, resultsLimit: 1)
        guard existing.isEmpty else { throw GroupError.alreadyRequested }

        // Create the join request
        let request = JoinRequest(
            id: UUID().uuidString,
            groupID: groupID,
            userID: userID,
            username: username,
            status: .pending,
            createdAt: Date()
        )
        let record = Self.joinRequestRecord(from: request)
        try await database.save(record)
        Log.groups.info("Join request sent by \(userID) for group \(groupID)")
    }

    func fetchJoinRequests(groupID: String) async throws -> [JoinRequest] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "groupID == %@", groupID),
            NSPredicate(format: "status == %@", JoinRequestStatus.pending.rawValue)
        ])
        let query = CKQuery(recordType: "JoinRequest", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let (results, _) = try await database.records(matching: query)
        let requests = results.compactMap { _, result in
            try? result.get()
        }.map(Self.joinRequest(from:))

        Log.groups.debug("Fetched \(requests.count) pending requests for group \(groupID)")
        return requests
    }

    func acceptJoinRequest(requestID: String, groupID: String, userID: String) async throws {
        // Update join request status
        let requestRecordID = CKRecord.ID(recordName: requestID)
        let requestRecord = try await database.record(for: requestRecordID)
        requestRecord["status"] = JoinRequestStatus.accepted.rawValue as CKRecordValue

        // Add user to group's memberIDs
        let groupRecordID = CKRecord.ID(recordName: groupID)
        let groupRecord = try await database.record(for: groupRecordID)
        var memberIDs = groupRecord["memberIDs"] as? [String] ?? []

        guard memberIDs.count < 20 else { throw GroupError.groupFull }

        memberIDs.append(userID)
        groupRecord["memberIDs"] = memberIDs as CKRecordValue

        // Save both records
        _ = try await database.modifyRecords(saving: [requestRecord, groupRecord], deleting: [], savePolicy: .changedKeys)

        Log.groups.info("Accepted join request \(requestID) — user \(userID) added to group \(groupID)")
    }

    func declineJoinRequest(requestID: String) async throws {
        let recordID = CKRecord.ID(recordName: requestID)
        let record = try await database.record(for: recordID)
        record["status"] = JoinRequestStatus.declined.rawValue as CKRecordValue
        try await database.save(record)
        Log.groups.info("Declined join request \(requestID)")
    }

    // MARK: - Membership

    func leaveGroup(groupID: String, userID: String) async throws {
        let groupRecordID = CKRecord.ID(recordName: groupID)
        let groupRecord = try await database.record(for: groupRecordID)
        let group = Self.group(from: groupRecord)

        guard group.adminID != userID else { throw GroupError.adminCannotLeave }

        var memberIDs = groupRecord["memberIDs"] as? [String] ?? []
        memberIDs.removeAll { $0 == userID }
        groupRecord["memberIDs"] = memberIDs as CKRecordValue
        try await database.save(groupRecord)

        Log.groups.info("User \(userID) left group \(groupID)")
    }

    func removeMember(groupID: String, userID: String) async throws {
        let groupRecordID = CKRecord.ID(recordName: groupID)
        let groupRecord = try await database.record(for: groupRecordID)

        var memberIDs = groupRecord["memberIDs"] as? [String] ?? []
        memberIDs.removeAll { $0 == userID }
        groupRecord["memberIDs"] = memberIDs as CKRecordValue
        try await database.save(groupRecord)

        Log.groups.info("Removed member \(userID) from group \(groupID)")
    }

    // MARK: - Helpers

    private func generateUniqueCode() async throws -> String {
        for _ in 0..<10 {
            let code = GroupCodeGenerator.generate()
            let predicate = NSPredicate(format: "code == %@", code)
            let query = CKQuery(recordType: "Group", predicate: predicate)
            let (results, _) = try await database.records(matching: query, resultsLimit: 1)
            if results.isEmpty { return code }
        }
        // With 30^6 ≈ 729M possible codes, collision after 10 attempts is essentially impossible
        return GroupCodeGenerator.generate()
    }

    // MARK: - Record Conversion (Group)

    private static func group(from record: CKRecord) -> Group {
        Group(
            id: record.recordID.recordName,
            name: record["name"] as? String ?? "",
            code: record["code"] as? String ?? "",
            adminID: record["adminID"] as? String ?? "",
            memberIDs: record["memberIDs"] as? [String] ?? [],
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date()
        )
    }

    private static func record(from group: Group) -> CKRecord {
        let recordID = CKRecord.ID(recordName: group.id)
        let record = CKRecord(recordType: "Group", recordID: recordID)
        record["name"] = group.name as CKRecordValue
        record["code"] = group.code as CKRecordValue
        record["adminID"] = group.adminID as CKRecordValue
        record["memberIDs"] = group.memberIDs as CKRecordValue
        record["createdAt"] = group.createdAt as CKRecordValue
        return record
    }

    // MARK: - Record Conversion (JoinRequest)

    private static func joinRequest(from record: CKRecord) -> JoinRequest {
        JoinRequest(
            id: record.recordID.recordName,
            groupID: record["groupID"] as? String ?? "",
            userID: record["userID"] as? String ?? "",
            username: record["username"] as? String ?? "",
            status: JoinRequestStatus(rawValue: record["status"] as? String ?? "") ?? .pending,
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date()
        )
    }

    private static func joinRequestRecord(from request: JoinRequest) -> CKRecord {
        let recordID = CKRecord.ID(recordName: request.id)
        let record = CKRecord(recordType: "JoinRequest", recordID: recordID)
        record["groupID"] = request.groupID as CKRecordValue
        record["userID"] = request.userID as CKRecordValue
        record["username"] = request.username as CKRecordValue
        record["status"] = request.status.rawValue as CKRecordValue
        record["createdAt"] = request.createdAt as CKRecordValue
        return record
    }
}
