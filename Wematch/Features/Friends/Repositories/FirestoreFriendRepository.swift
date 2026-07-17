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

        // Pending in either direction blocks a new request.
        async let outgoing = database.collection("friendRequests")
            .whereField("senderID", isEqualTo: senderID)
            .whereField("receiverID", isEqualTo: receiverID)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1).getDocuments()
        async let incoming = database.collection("friendRequests")
            .whereField("senderID", isEqualTo: receiverID)
            .whereField("receiverID", isEqualTo: senderID)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1).getDocuments()
        let (outgoingDocs, incomingDocs) = try await (outgoing.documents, incoming.documents)
        guard outgoingDocs.isEmpty && incomingDocs.isEmpty else { throw FriendError.alreadyRequested }

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
        async let friendships = database.collection("friendships")
            .whereField("userIDs", arrayContains: userID).getDocuments()
        async let sent = database.collection("friendRequests")
            .whereField("senderID", isEqualTo: userID).getDocuments()
        async let received = database.collection("friendRequests")
            .whereField("receiverID", isEqualTo: userID).getDocuments()

        let docs = try await friendships.documents + sent.documents + received.documents
        guard !docs.isEmpty else { return }
        let batch = database.batch()
        for doc in docs {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        Log.friends.info("Deleted \(docs.count) friend-related documents")
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
