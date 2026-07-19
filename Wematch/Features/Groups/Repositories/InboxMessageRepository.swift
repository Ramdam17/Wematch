import Foundation

/// Delivery-side inbox abstraction: writes a notification message into
/// ANOTHER user's inbox. Reading one's own inbox is `InboxRepository`.
/// (Lives under Features/Groups for historical reasons — relocation is
/// planned in step 3c, audit H6.)
protocol InboxMessageRepository: Sendable {
    func createMessage(recipientID: String, type: InboxMessageType, payload: [String: String]) async throws
}
