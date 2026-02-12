import Foundation

protocol RoomRepository: Sendable {
    func fetchActiveRooms() async throws -> [Room]
    func joinRoom(roomID: String) async throws
    func leaveRoom(roomID: String) async throws
}
