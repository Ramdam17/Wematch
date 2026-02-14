import Foundation

protocol TemporaryRoomRepository: Sendable {
    func createRoom(roomID: String, userA: String, userB: String,
                    userAUsername: String, userBUsername: String) async throws
    func fetchActiveRooms(userID: String) async throws -> [TemporaryRoom]
    func deleteRoom(roomID: String, userA: String, userB: String) async throws
    func hasParticipants(roomID: String) async throws -> Bool
}
