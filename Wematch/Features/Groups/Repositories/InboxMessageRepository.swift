import Foundation
import OSLog

/// Delivery-side inbox abstraction: writes a notification message into
/// ANOTHER user's inbox. Reading one's own inbox is `InboxRepository`.
/// (Lives under Features/Groups for historical reasons — relocation is
/// planned in step 3c, audit H6.)
protocol InboxMessageRepository: Sendable {
    func createMessage(recipientID: String, type: InboxMessageType, payload: [String: String]) async throws
}

extension InboxMessageRepository {
    /// Best-effort delivery: the action the message announces (a request accepted, a group
    /// deleted) has already succeeded, and its outcome is not held hostage to a courtesy
    /// message reaching the other person's inbox. What it must never be is *silent* —
    /// six call sites used to `try?` this and no log ever said a notification was lost
    /// (audit D3, plan 1.8).
    ///
    /// Returns whether the message was delivered, for the rare caller that wants to say so.
    @discardableResult
    func notify(recipientID: String, type: InboxMessageType, payload: [String: String]) async -> Bool {
        do {
            try await createMessage(recipientID: recipientID, type: type, payload: payload)
            return true
        } catch {
            Log.inbox.error("""
                Notification \(type.rawValue) to \(recipientID, privacy: .private) not delivered: \
                \(error.localizedDescription)
                """)
            return false
        }
    }
}
