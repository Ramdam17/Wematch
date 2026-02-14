import Foundation

protocol InboxRepository: Sendable {
    func fetchMessages(userID: String) async throws -> [InboxMessage]
    func markAsRead(messageID: String) async throws
    func markAllAsRead(userID: String) async throws
    func deleteMessage(messageID: String) async throws
    func unreadCount(userID: String) async throws -> Int

    // Account deletion
    func deleteAllMessages(userID: String) async throws
}
