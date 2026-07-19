import Foundation
import FirebaseCore
import FirebaseFirestore
import OSLog

/// Firestore-backed groups (plan 1.2b). Documents at `groups/{groupID}`,
/// join requests at `joinRequests/{requestID}`. All IDs are Firebase UIDs.
struct FirestoreGroupRepository: GroupRepository {

    private static let maxMembers = 20

    private var database: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }

    // MARK: - Groups

    func fetchMyGroups(userID: String) async throws -> [Group] {
        guard let database else { throw FirebaseAuthError.notConfigured }
        // Firestore has no OR queries across fields — run both and merge.
        async let asAdmin = database.collection("groups")
            .whereField("adminID", isEqualTo: userID).getDocuments()
        async let asMember = database.collection("groups")
            .whereField("memberIDs", arrayContains: userID).getDocuments()

        let docs = try await asAdmin.documents + asMember.documents
        var seen = Set<String>()
        return docs.compactMap { doc in
            guard seen.insert(doc.documentID).inserted else { return nil }
            return Self.group(from: doc)
        }
    }

    func createGroup(name: String, adminID: String) async throws -> Group {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupError.emptyName }

        // Retry code generation on (rare) collisions.
        var code = GroupCodeGenerator.generate()
        for _ in 0..<5 {
            let clash = try await database.collection("groups")
                .whereField("code", isEqualTo: code).limit(to: 1).getDocuments()
            if clash.documents.isEmpty { break }
            code = GroupCodeGenerator.generate()
        }

        let ref = database.collection("groups").document()
        let createdAt = Date()
        try await ref.setData([
            "name": trimmedName,
            "code": code,
            "adminID": adminID,
            "memberIDs": [String](),
            "createdAt": Timestamp(date: createdAt)
        ])
        Log.groups.info("Created group \(ref.documentID)")
        return Group(id: ref.documentID, name: trimmedName, code: code,
                     adminID: adminID, memberIDs: [], createdAt: createdAt)
    }

    func deleteGroup(groupID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let requests = try await database.collection("joinRequests")
            .whereField("groupID", isEqualTo: groupID).getDocuments()

        let batch = database.batch()
        batch.deleteDocument(database.collection("groups").document(groupID))
        for doc in requests.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        Log.groups.info("Deleted group \(groupID) and \(requests.documents.count) join requests")
    }

    func searchGroups(query: String) async throws -> [Group] {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        // Prefix search (Firestore has no `contains`); case-sensitive like the
        // CloudKit BEGINSWITH it replaces.
        let snapshot = try await database.collection("groups")
            .whereField("name", isGreaterThanOrEqualTo: trimmed)
            .whereField("name", isLessThan: trimmed + "\u{f8ff}")
            .limit(to: 25)
            .getDocuments()
        return snapshot.documents.compactMap(Self.group(from:))
    }

    func fetchGroup(byCode code: String) async throws -> Group? {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await database.collection("groups")
            .whereField("code", isEqualTo: code.uppercased())
            .limit(to: 1).getDocuments()
        return snapshot.documents.first.flatMap(Self.group(from:))
    }

    // MARK: - Join requests

    func sendJoinRequest(groupID: String, userID: String, username: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let groupDoc = try await database.collection("groups").document(groupID).getDocument()
        guard let group = Self.group(from: groupDoc) else { throw GroupError.groupNotFound }
        guard group.memberIDs.count < Self.maxMembers else { throw GroupError.groupFull }
        guard group.adminID != userID, !group.memberIDs.contains(userID) else {
            throw GroupError.alreadyMember
        }

        let existing = try await database.collection("joinRequests")
            .whereField("groupID", isEqualTo: groupID)
            .whereField("userID", isEqualTo: userID)
            .whereField("status", isEqualTo: JoinRequestStatus.pending.rawValue)
            .limit(to: 1).getDocuments()
        guard existing.documents.isEmpty else { throw GroupError.alreadyRequested }

        try await database.collection("joinRequests").document().setData([
            "groupID": groupID,
            "userID": userID,
            "username": username,
            "status": JoinRequestStatus.pending.rawValue,
            "createdAt": Timestamp(date: Date())
        ])
        Log.groups.info("Join request sent for group \(groupID)")
    }

    func fetchJoinRequests(groupID: String) async throws -> [JoinRequest] {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await database.collection("joinRequests")
            .whereField("groupID", isEqualTo: groupID)
            .whereField("status", isEqualTo: JoinRequestStatus.pending.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap(Self.joinRequest(from:))
    }

    func acceptJoinRequest(requestID: String, groupID: String, userID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let groupDoc = try await database.collection("groups").document(groupID).getDocument()
        guard let group = Self.group(from: groupDoc) else { throw GroupError.groupNotFound }
        guard group.memberIDs.count < Self.maxMembers else { throw GroupError.groupFull }

        let batch = database.batch()
        batch.updateData(["memberIDs": FieldValue.arrayUnion([userID])],
                         forDocument: database.collection("groups").document(groupID))
        batch.updateData(["status": JoinRequestStatus.accepted.rawValue],
                         forDocument: database.collection("joinRequests").document(requestID))
        try await batch.commit()
        Log.groups.info("Accepted join request \(requestID) for group \(groupID)")
    }

    func declineJoinRequest(requestID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        try await database.collection("joinRequests").document(requestID)
            .updateData(["status": JoinRequestStatus.declined.rawValue])
    }

    // MARK: - Membership

    func leaveGroup(groupID: String, userID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let groupDoc = try await database.collection("groups").document(groupID).getDocument()
        guard let group = Self.group(from: groupDoc) else { throw GroupError.groupNotFound }
        guard group.adminID != userID else { throw GroupError.adminCannotLeave }
        try await database.collection("groups").document(groupID)
            .updateData(["memberIDs": FieldValue.arrayRemove([userID])])
        Log.groups.info("User left group \(groupID)")
    }

    func removeMember(groupID: String, userID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        try await database.collection("groups").document(groupID)
            .updateData(["memberIDs": FieldValue.arrayRemove([userID])])
        Log.groups.info("Removed member from group \(groupID)")
    }

    // MARK: - Account deletion

    func fetchAdminGroups(userID: String) async throws -> [Group] {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await database.collection("groups")
            .whereField("adminID", isEqualTo: userID).getDocuments()
        return snapshot.documents.compactMap(Self.group(from:))
    }

    func removeUserFromAllGroups(userID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await database.collection("groups")
            .whereField("memberIDs", arrayContains: userID).getDocuments()
        guard !snapshot.documents.isEmpty else { return }
        let batch = database.batch()
        for doc in snapshot.documents {
            batch.updateData(["memberIDs": FieldValue.arrayRemove([userID])],
                             forDocument: doc.reference)
        }
        try await batch.commit()
        Log.groups.info("Removed user from \(snapshot.documents.count) groups")
    }

    // MARK: - Mapping

    private static func group(from doc: DocumentSnapshot) -> Group? {
        guard doc.exists, let data = doc.data() else { return nil }
        guard let name = data["name"] as? String,
              let code = data["code"] as? String,
              let adminID = data["adminID"] as? String else {
            Log.groups.error("Malformed group document \(doc.documentID) — dropped")
            return nil
        }
        return Group(
            id: doc.documentID,
            name: name,
            code: code,
            adminID: adminID,
            memberIDs: data["memberIDs"] as? [String] ?? [],
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private static func joinRequest(from doc: DocumentSnapshot) -> JoinRequest? {
        guard doc.exists, let data = doc.data() else { return nil }
        guard let groupID = data["groupID"] as? String,
              let userID = data["userID"] as? String,
              let statusRaw = data["status"] as? String,
              let status = JoinRequestStatus(rawValue: statusRaw) else {
            Log.groups.error("Malformed join request \(doc.documentID) — dropped")
            return nil
        }
        return JoinRequest(
            id: doc.documentID,
            groupID: groupID,
            userID: userID,
            username: data["username"] as? String ?? "",
            status: status,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}
