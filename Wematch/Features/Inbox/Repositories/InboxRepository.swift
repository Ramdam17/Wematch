import Foundation

protocol InboxRepository: Sendable {
    func fetchMessages() async throws -> [InboxMessage]
    func markAsRead(messageID: String) async throws
    func performAction(messageID: String, action: InboxAction) async throws
}
