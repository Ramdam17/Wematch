import Foundation
import FirebaseCore
import FirebaseFirestore
import OSLog

/// Firestore-backed inbox (plan 1.2b). Messages live under
/// `inbox/{recipientUID}/messages/{messageID}` — the recipient-scoped layout
/// the security rules are built around (anyone signed-in delivers, only the
/// recipient reads).
struct FirestoreInboxRepository: InboxRepository {

    private var database: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }

    private func messages(of userID: String, in database: Firestore) -> CollectionReference {
        database.collection("inbox").document(userID).collection("messages")
    }

    func fetchMessages(userID: String) async throws -> [InboxMessage] {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await messages(of: userID, in: database)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { Self.message(from: $0, recipientID: userID) }
    }

    func markAsRead(messageID: String) async throws {
        guard let database, let uid = currentUID else { throw FirebaseAuthError.notConfigured }
        try await messages(of: uid, in: database).document(messageID)
            .updateData(["isRead": true])
    }

    func markAllAsRead(userID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let unread = try await messages(of: userID, in: database)
            .whereField("isRead", isEqualTo: false).getDocuments()
        guard !unread.documents.isEmpty else { return }
        let batch = database.batch()
        for doc in unread.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    func deleteMessage(messageID: String) async throws {
        guard let database, let uid = currentUID else { throw FirebaseAuthError.notConfigured }
        try await messages(of: uid, in: database).document(messageID).delete()
    }

    func unreadCount(userID: String) async throws -> Int {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await messages(of: userID, in: database)
            .whereField("isRead", isEqualTo: false)
            .count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    func deleteAllMessages(userID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let all = try await messages(of: userID, in: database).getDocuments()
        guard !all.documents.isEmpty else { return }
        let batch = database.batch()
        for doc in all.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        Log.inbox.info("Deleted \(all.documents.count) inbox messages")
    }

    // MARK: - Helpers

    /// markAsRead/deleteMessage receive only a messageID (protocol shape kept
    /// from v1) — the recipient is necessarily the signed-in user.
    private var currentUID: String? {
        guard FirebaseApp.app() != nil else { return nil }
        return FirebaseAuthService().currentUID
    }

    private static func message(from doc: DocumentSnapshot, recipientID: String) -> InboxMessage? {
        guard doc.exists, let data = doc.data(),
              let typeRaw = data["type"] as? String else { return nil }
        guard let type = InboxMessageType(rawValue: typeRaw) else {
            // Unknown type (newer app version?) — logged, not silently vanished
            // into thin air. A proper `.unknown` case is plan step 1.7 (D3).
            Log.inbox.warning("Unknown inbox message type '\(typeRaw)' in \(doc.documentID) — skipped")
            return nil
        }
        return InboxMessage(
            id: doc.documentID,
            recipientID: recipientID,
            type: type,
            payload: data["payload"] as? [String: String] ?? [:],
            isRead: data["isRead"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

// MARK: - Message delivery (writes into ANOTHER user's inbox)

struct FirestoreInboxMessageRepository: InboxMessageRepository {

    private let firebaseAuth: any FirebaseAuthenticating

    init(firebaseAuth: (any FirebaseAuthenticating)? = nil) {
        self.firebaseAuth = firebaseAuth ?? FirebaseAuthService()
    }

    func createMessage(recipientID: String, type: InboxMessageType, payload: [String: String]) async throws {
        guard FirebaseApp.app() != nil, let senderID = firebaseAuth.currentUID else {
            throw FirebaseAuthError.notConfigured
        }
        try await Firestore.firestore()
            .collection("inbox").document(recipientID).collection("messages")
            .document().setData([
                "type": type.rawValue,
                "senderID": senderID,
                "payload": payload,
                "isRead": false,
                "createdAt": Timestamp(date: Date())
            ])
        Log.inbox.info("Delivered inbox message type=\(type.rawValue)")
    }
}
