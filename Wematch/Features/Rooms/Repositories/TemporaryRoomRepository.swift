import Foundation

protocol TemporaryRoomRepository: Sendable {
    func createRoom(roomID: String, userA: String, userB: String,
                    userAUsername: String, userBUsername: String) async throws
    func fetchActiveRooms(userID: String) async throws -> [TemporaryRoom]
    /// Destroys the room and both members' index entries. Member IDs are
    /// resolved from the room's own metadata — callers never derive them
    /// from the roomID string (audit E1).
    func deleteRoom(roomID: String) async throws
    func hasParticipants(roomID: String) async throws -> Bool
}
