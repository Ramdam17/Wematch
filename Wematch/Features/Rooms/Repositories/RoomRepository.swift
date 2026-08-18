import Foundation

protocol RoomRepository: Sendable {
    func joinRoom(roomID: String, participant: RoomParticipant) async throws
    func leaveRoom(roomID: String, userID: String) async throws
    func updateHeartRate(roomID: String, userID: String, data: HeartRateData, username: String, slot: HeartPaletteSlot) async throws
    /// Throwing for the reason the Firebase layer is (plan 1.7, D2): the caller has to
    /// be able to tell "nobody is here" from "we lost the room".
    /// True while the device is reaching the database. See
    /// `FirebaseServiceProtocol.observeConnection`.
    func observeConnection() -> AsyncStream<Bool>
    func observeParticipants(roomID: String) -> AsyncThrowingStream<[RoomParticipant], Error>
}
