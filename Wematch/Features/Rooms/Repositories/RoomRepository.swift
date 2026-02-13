import Foundation

protocol RoomRepository: Sendable {
    func joinRoom(roomID: String, participant: RoomParticipant) async throws
    func leaveRoom(roomID: String, userID: String) async throws
    func updateHeartRate(roomID: String, userID: String, data: HeartRateData, username: String, color: String) async throws
    func observeParticipants(roomID: String) -> AsyncStream<[RoomParticipant]>
}
