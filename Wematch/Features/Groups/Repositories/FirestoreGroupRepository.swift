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
        // Firestore has no OR queries across fields — run both and merge.
        //
        // Each branch builds its own query *and* maps the result inside its own child
        // task. `Firestore`, `Query` and `QueryDocumentSnapshot` are none of them
        // `Sendable`, so an `async let` that captured the handle from here — or handed
        // back snapshots — would be sending non-`Sendable` values across a concurrency
        // boundary. `Group` is `Sendable`, so that is what crosses (plan 1.10).
        async let asAdmin = Self.groups { $0.whereField("adminID", isEqualTo: userID) }
        async let asMember = Self.groups { $0.whereField("memberIDs", arrayContains: userID) }

        let found = try await asAdmin + asMember
        var seen = Set<String>()
        return found.filter { seen.insert($0.id).inserted }
    }

    /// Runs one groups query and maps it, entirely within the caller's task.
    private static func groups(
        _ narrow: @Sendable (CollectionReference) -> Query
    ) async throws -> [Group] {
        guard FirebaseApp.app() != nil else { throw FirebaseAuthError.notConfigured }
        let collection = Firestore.firestore().collection("groups")
        let snapshot = try await narrow(collection).getDocuments()
        return snapshot.documents.compactMap { group(from: $0) }
    }

    func createGroup(name: String, adminID: String) async throws -> Group {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupError.emptyName }

        // Code uniqueness is a reservation document, `groupCodes/{code}`, claimed in the
        // same transaction that creates the group — the pattern `usernames/{username}`
        // already uses. The previous shape was query-then-write: two users drawing the
        // same code between the check and the write both got it (plan 1.8, audit D4).
        // A transaction cannot run a query, only read documents by path, which is why the
        // uniqueness lives in a document keyed by the code and not in a `whereField`.
        // Reads must all precede writes inside the block, and the block may be re-run.
        let groupID = database.collection("groups").document().documentID
        let createdAt = Date()
        // The block captures only `Sendable` values (strings, a date) and re-obtains the
        // Firestore handle inside: `Firestore`, `CollectionReference` and
        // `DocumentReference` are not `Sendable`, and the block runs on the SDK's queue.
        // The SDK's own `async` overload of `runTransaction` is written in Swift and takes
        // a `sending` block; from a main-actor repository that means sending `Firestore`
        // — which is not `Sendable` — and the compiler refuses. The Objective-C form with a
        // completion block is `@preconcurrency` by import, so it is wrapped by hand here.
        let result: String? = try await withCheckedThrowingContinuation { continuation in
            database.runTransaction({ @Sendable transaction, errorPointer in
                let firestore = Firestore.firestore()
                let ref = firestore.collection("groups").document(groupID)
                let codes = firestore.collection("groupCodes")
                var chosen: String?
                for _ in 0..<Self.codeAttempts {
                    let candidate = GroupCodeGenerator.generate()
                    do {
                        let reservation = try transaction.getDocument(codes.document(candidate))
                        if !reservation.exists { chosen = candidate; break }
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                }
                guard let code = chosen else {
                    errorPointer?.pointee = GroupError.codeSpaceExhausted as NSError
                    return nil
                }
                transaction.setData([
                    "name": trimmedName,
                    "code": code,
                    "adminID": adminID,
                    "memberIDs": [String](),
                    "createdAt": Timestamp(date: createdAt)
                ], forDocument: ref)
                transaction.setData(["groupID": groupID, "adminID": adminID],
                                    forDocument: codes.document(code))
                return code
            }, completion: { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    // `Any?` is not `Sendable`; the `String` the block returns is.
                    continuation.resume(returning: value as? String)
                }
            })
        }
        guard let code = result else {
            // The block returns the code or sets the error; anything else is a bug here.
            throw GroupError.codeSpaceExhausted
        }
        Log.groups.info("Created group \(groupID)")
        return Group(id: groupID, name: trimmedName, code: code,
                     adminID: adminID, memberIDs: [], createdAt: createdAt)
    }

    /// Draws per transaction. 32⁶ ≈ 1.07 × 10⁹ codes: with even ten thousand groups
    /// the chance one draw collides is ~10⁻⁵, and of five in a row ~10⁻²⁵ — the guard is
    /// against a bug (a generator returning constants), not against arithmetic.
    private nonisolated static let codeAttempts = 5

    func deleteGroup(groupID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let requests = try await database.collection("joinRequests")
            .whereField("groupID", isEqualTo: groupID).getDocuments()

        let groupRef = database.collection("groups").document(groupID)
        let batch = database.batch()
        batch.deleteDocument(groupRef)
        // Free the code with the group, or the reservation would outlive it and the code
        // could never be drawn again.
        if let code = try await groupRef.getDocument().get("code") as? String {
            batch.deleteDocument(database.collection("groupCodes").document(code))
        }
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
