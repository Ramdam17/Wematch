import CloudKit
import OSLog

final class CloudKitFriendRepository: FriendRepository {

    private let database: CKDatabase

    init(database: CKDatabase = CloudKitManager.shared.publicDatabase) {
        self.database = database
    }

    // MARK: - Friends

    func fetchFriends(userID: String) async throws -> [Friendship] {
        // CloudKit doesn't support OR — run two queries in parallel
        async let results1 = fetchFriendships(predicate: NSPredicate(format: "userID1 == %@", userID))
        async let results2 = fetchFriendships(predicate: NSPredicate(format: "userID2 == %@", userID))

        let all = try await results1 + results2
        var seen = Set<String>()
        let unique = all.filter { seen.insert($0.id).inserted }

        Log.friends.debug("Fetched \(unique.count) friendships for user \(userID)")
        return unique
    }

    func removeFriend(friendshipID: String) async throws {
        let recordID = CKRecord.ID(recordName: friendshipID)
        try await database.deleteRecord(withID: recordID)
        Log.friends.info("Removed friendship \(friendshipID)")
    }

    // MARK: - Requests

    func sendFriendRequest(senderID: String, receiverID: String,
                           senderUsername: String, receiverUsername: String) async throws {
        guard senderID != receiverID else { throw FriendError.selfRequest }

        // Check not already friends
        let friendships = try await fetchFriends(userID: senderID)
        let isFriend = friendships.contains { f in
            f.friendID(for: senderID) == receiverID
        }
        guard !isFriend else { throw FriendError.alreadyFriends }

        // Check no pending request in either direction
        let hasPending = try await hasPendingRequest(between: senderID, and: receiverID)
        guard !hasPending else { throw FriendError.alreadyRequested }

        let request = FriendRequest(
            id: UUID().uuidString,
            senderID: senderID,
            receiverID: receiverID,
            senderUsername: senderUsername,
            receiverUsername: receiverUsername,
            status: .pending,
            createdAt: Date()
        )
        let record = Self.friendRequestRecord(from: request)
        try await database.save(record)
        Log.friends.info("Friend request sent from \(senderUsername) to \(receiverUsername)")
    }

    func fetchIncomingRequests(userID: String) async throws -> [FriendRequest] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "receiverID == %@", userID),
            NSPredicate(format: "status == %@", FriendRequestStatus.pending.rawValue)
        ])
        return try await fetchRequests(predicate: predicate)
    }

    func fetchOutgoingRequests(userID: String) async throws -> [FriendRequest] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "senderID == %@", userID),
            NSPredicate(format: "status == %@", FriendRequestStatus.pending.rawValue)
        ])
        return try await fetchRequests(predicate: predicate)
    }

    @discardableResult
    func acceptFriendRequest(_ request: FriendRequest) async throws -> Friendship {
        // Update request status
        let requestRecordID = CKRecord.ID(recordName: request.id)
        let requestRecord = try await database.record(for: requestRecordID)
        requestRecord["status"] = FriendRequestStatus.accepted.rawValue as CKRecordValue

        // Create friendship
        let friendship = Friendship(
            id: UUID().uuidString,
            userID1: request.senderID,
            userID2: request.receiverID,
            createdAt: Date()
        )
        let friendshipRecord = Self.friendshipRecord(from: friendship)

        // Save both atomically
        _ = try await database.modifyRecords(saving: [requestRecord, friendshipRecord], deleting: [], savePolicy: .changedKeys)

        Log.friends.info("Accepted friend request from \(request.senderUsername) — friendship created")
        return friendship
    }

    func declineFriendRequest(requestID: String) async throws {
        let recordID = CKRecord.ID(recordName: requestID)
        let record = try await database.record(for: recordID)
        record["status"] = FriendRequestStatus.declined.rawValue as CKRecordValue
        try await database.save(record)
        Log.friends.info("Declined friend request \(requestID)")
    }

    func cancelFriendRequest(requestID: String) async throws {
        let recordID = CKRecord.ID(recordName: requestID)
        try await database.deleteRecord(withID: recordID)
        Log.friends.info("Canceled friend request \(requestID)")
    }

    // MARK: - Search

    func searchUsers(query: String, excludingUserID: String) async throws -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let predicate = NSPredicate(format: "username BEGINSWITH[c] %@", trimmed)
        let ckQuery = CKQuery(recordType: "UserProfile", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)]

        do {
            let (results, _) = try await database.records(matching: ckQuery, resultsLimit: 20)
            let profiles = results.compactMap { _, result in
                try? result.get()
            }.map(Self.userProfile(from:)).filter { $0.id != excludingUserID }

            Log.friends.debug("Search '\(trimmed)' returned \(profiles.count) users")
            return profiles
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
    }

    // MARK: - Helpers

    private func fetchFriendships(predicate: NSPredicate) async throws -> [Friendship] {
        let query = CKQuery(recordType: "Friendship", predicate: predicate)
        do {
            let (results, _) = try await database.records(matching: query)
            return results.compactMap { _, result in try? result.get() }.map(Self.friendship(from:))
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
    }

    private func fetchRequests(predicate: NSPredicate) async throws -> [FriendRequest] {
        let query = CKQuery(recordType: "FriendRequest", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let (results, _) = try await database.records(matching: query)
            return results.compactMap { _, result in try? result.get() }.map(Self.friendRequest(from:))
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
    }

    private func hasPendingRequest(between userA: String, and userB: String) async throws -> Bool {
        // Check A→B
        let predAB = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "senderID == %@", userA),
            NSPredicate(format: "receiverID == %@", userB),
            NSPredicate(format: "status == %@", FriendRequestStatus.pending.rawValue)
        ])
        let abResults = try await fetchRequests(predicate: predAB)
        if !abResults.isEmpty { return true }

        // Check B→A
        let predBA = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "senderID == %@", userB),
            NSPredicate(format: "receiverID == %@", userA),
            NSPredicate(format: "status == %@", FriendRequestStatus.pending.rawValue)
        ])
        let baResults = try await fetchRequests(predicate: predBA)
        return !baResults.isEmpty
    }

    // MARK: - Record Conversion (Friendship)

    private static func friendship(from record: CKRecord) -> Friendship {
        Friendship(
            id: record.recordID.recordName,
            userID1: record["userID1"] as? String ?? "",
            userID2: record["userID2"] as? String ?? "",
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date()
        )
    }

    private static func friendshipRecord(from friendship: Friendship) -> CKRecord {
        let recordID = CKRecord.ID(recordName: friendship.id)
        let record = CKRecord(recordType: "Friendship", recordID: recordID)
        record["userID1"] = friendship.userID1 as CKRecordValue
        record["userID2"] = friendship.userID2 as CKRecordValue
        record["createdAt"] = friendship.createdAt as CKRecordValue
        return record
    }

    // MARK: - Record Conversion (FriendRequest)

    private static func friendRequest(from record: CKRecord) -> FriendRequest {
        FriendRequest(
            id: record.recordID.recordName,
            senderID: record["senderID"] as? String ?? "",
            receiverID: record["receiverID"] as? String ?? "",
            senderUsername: record["senderUsername"] as? String ?? "",
            receiverUsername: record["receiverUsername"] as? String ?? "",
            status: FriendRequestStatus(rawValue: record["status"] as? String ?? "") ?? .pending,
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date()
        )
    }

    private static func friendRequestRecord(from request: FriendRequest) -> CKRecord {
        let recordID = CKRecord.ID(recordName: request.id)
        let record = CKRecord(recordType: "FriendRequest", recordID: recordID)
        record["senderID"] = request.senderID as CKRecordValue
        record["receiverID"] = request.receiverID as CKRecordValue
        record["senderUsername"] = request.senderUsername as CKRecordValue
        record["receiverUsername"] = request.receiverUsername as CKRecordValue
        record["status"] = request.status.rawValue as CKRecordValue
        record["createdAt"] = request.createdAt as CKRecordValue
        return record
    }

    // MARK: - Record Conversion (UserProfile — read-only)

    private static func userProfile(from record: CKRecord) -> UserProfile {
        UserProfile(
            id: record.recordID.recordName,
            username: record["username"] as? String ?? "",
            displayName: record["displayName"] as? String,
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? Date(),
            usernameEdited: (record["usernameEdited"] as? Int64 ?? 0) != 0
        )
    }
}
