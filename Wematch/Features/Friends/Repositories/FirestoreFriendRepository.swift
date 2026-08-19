import Foundation
import FirebaseCore
import FirebaseFirestore
import OSLog

/// Firestore-backed friendships (plan 1.2b). Friendships store a `userIDs`
/// array (rules + array-contains queries); requests live at
/// `friendRequests/{requestID}`. All IDs are Firebase UIDs.
struct FirestoreFriendRepository: FriendRepository {

    private var database: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }

    // MARK: - Friends

    func fetchFriends(userID: String) async throws -> [Friendship] {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await database.collection("friendships")
            .whereField("userIDs", arrayContains: userID).getDocuments()
        return snapshot.documents.compactMap(Self.friendship(from:))
    }

    func removeFriend(friendshipID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        try await database.collection("friendships").document(friendshipID).delete()
        Log.friends.info("Removed friendship \(friendshipID)")
    }

    // MARK: - Requests

    func sendFriendRequest(senderID: String, receiverID: String,
                           senderUsername: String, receiverUsername: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        guard senderID != receiverID else { throw FriendError.selfRequest }

        let friendships = try await fetchFriends(userID: senderID)
        let isFriend = friendships.contains {
            $0.userID1 == receiverID || $0.userID2 == receiverID
        }
        guard !isFriend else { throw FriendError.alreadyFriends }

        // Pending in either direction blocks a new request. Only the count crosses back:
        // `QueryDocumentSnapshot` is not `Sendable` (plan 1.10).
        async let outgoing = Self.requestPaths(senderID: senderID, receiverID: receiverID, pendingOnly: true)
        async let incoming = Self.requestPaths(senderID: receiverID, receiverID: senderID, pendingOnly: true)
        let (outgoingPaths, incomingPaths) = try await (outgoing, incoming)
        guard outgoingPaths.isEmpty && incomingPaths.isEmpty else { throw FriendError.alreadyRequested }

        try await database.collection("friendRequests").document().setData([
            "senderID": senderID,
            "receiverID": receiverID,
            "senderUsername": senderUsername,
            "receiverUsername": receiverUsername,
            "status": FriendRequestStatus.pending.rawValue,
            "createdAt": Timestamp(date: Date())
        ])
        Log.friends.info("Friend request sent")
    }

    func fetchIncomingRequests(userID: String) async throws -> [FriendRequest] {
        try await fetchRequests(field: "receiverID", userID: userID)
    }

    func fetchOutgoingRequests(userID: String) async throws -> [FriendRequest] {
        try await fetchRequests(field: "senderID", userID: userID)
    }

    func acceptFriendRequest(_ request: FriendRequest) async throws -> Friendship {
        guard let database else { throw FirebaseAuthError.notConfigured }

        let friendshipRef = database.collection("friendships").document()
        let createdAt = Date()
        let batch = database.batch()
        batch.setData([
            "userIDs": [request.senderID, request.receiverID],
            "createdAt": Timestamp(date: createdAt)
        ], forDocument: friendshipRef)
        batch.updateData(["status": FriendRequestStatus.accepted.rawValue],
                         forDocument: database.collection("friendRequests").document(request.id))
        try await batch.commit()

        Log.friends.info("Friend request accepted")
        return Friendship(id: friendshipRef.documentID,
                          userID1: request.senderID,
                          userID2: request.receiverID,
                          createdAt: createdAt)
    }

    func declineFriendRequest(requestID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        try await database.collection("friendRequests").document(requestID)
            .updateData(["status": FriendRequestStatus.declined.rawValue])
    }

    func cancelFriendRequest(requestID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        try await database.collection("friendRequests").document(requestID).delete()
    }

    // MARK: - Search

    func searchUsers(query: String, excludingUserID: String) async throws -> [UserProfile] {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let snapshot = try await database.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: trimmed)
            .whereField("username", isLessThan: trimmed + "\u{f8ff}")
            .limit(to: 25)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            guard doc.documentID != excludingUserID, let data = doc.data() as [String: Any]? else { return nil }
            return UserProfile(
                id: doc.documentID,
                username: data["username"] as? String ?? "",
                displayName: data["displayName"] as? String,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                usernameEdited: data["usernameEdited"] as? Bool ?? false
            )
        }
    }

    // MARK: - Account deletion

    func deleteAllFriendData(userID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }

        // Document *paths* cross back, not references: `DocumentReference` is not
        // `Sendable`, and a path is enough to rebuild one on this side (plan 1.10).
        async let friendships = Self.paths(in: "friendships") {
            $0.whereField("userIDs", arrayContains: userID)
        }
        async let sent = Self.paths(in: "friendRequests") {
            $0.whereField("senderID", isEqualTo: userID)
        }
        async let received = Self.paths(in: "friendRequests") {
            $0.whereField("receiverID", isEqualTo: userID)
        }

        let paths = try await friendships + sent + received
        guard !paths.isEmpty else { return }
        let batch = database.batch()
        for path in paths {
            batch.deleteDocument(database.document(path))
        }
        try await batch.commit()
        Log.friends.info("Deleted \(paths.count) friend-related documents")
    }

    // MARK: - Helpers

    private func fetchRequests(field: String, userID: String) async throws -> [FriendRequest] {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await database.collection("friendRequests")
            .whereField(field, isEqualTo: userID)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap(Self.friendRequest(from:))
    }

    /// Runs one query and returns the matching document paths, entirely within the
    /// caller's task. Nothing Firestore-shaped leaves it.
    private static func paths(
        in collection: String,
        _ narrow: @Sendable (CollectionReference) -> Query
    ) async throws -> [String] {
        guard FirebaseApp.app() != nil else { throw FirebaseAuthError.notConfigured }
        let reference = Firestore.firestore().collection(collection)
        let snapshot = try await narrow(reference).getDocuments()
        return snapshot.documents.map(\.reference.path)
    }

    private static func requestPaths(
        senderID: String,
        receiverID: String,
        pendingOnly: Bool
    ) async throws -> [String] {
        try await paths(in: "friendRequests") { collection in
            var query = collection
                .whereField("senderID", isEqualTo: senderID)
                .whereField("receiverID", isEqualTo: receiverID)
            if pendingOnly {
                query = query.whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            }
            return query.limit(to: 1)
        }
    }

    private static func friendship(from doc: DocumentSnapshot) -> Friendship? {
        guard doc.exists, let data = doc.data(),
              let userIDs = data["userIDs"] as? [String], userIDs.count == 2 else {
            Log.friends.error("Malformed friendship \(doc.documentID) — dropped")
            return nil
        }
        return Friendship(
            id: doc.documentID,
            userID1: userIDs[0],
            userID2: userIDs[1],
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private static func friendRequest(from doc: DocumentSnapshot) -> FriendRequest? {
        guard doc.exists, let data = doc.data(),
              let senderID = data["senderID"] as? String,
              let receiverID = data["receiverID"] as? String,
              let statusRaw = data["status"] as? String,
              let status = FriendRequestStatus(rawValue: statusRaw) else {
            Log.friends.error("Malformed friend request \(doc.documentID) — dropped")
            return nil
        }
        return FriendRequest(
            id: doc.documentID,
            senderID: senderID,
            receiverID: receiverID,
            senderUsername: data["senderUsername"] as? String ?? "",
            receiverUsername: data["receiverUsername"] as? String ?? "",
            status: status,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}
