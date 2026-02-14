import Foundation
import OSLog

final class FirebaseRoomRepository: RoomRepository, @unchecked Sendable {

    private let firebaseService: any FirebaseServiceProtocol

    init(firebaseService: (any FirebaseServiceProtocol)? = nil) {
        if let firebaseService {
            self.firebaseService = firebaseService
        } else if FirebaseManager.shared.database != nil {
            self.firebaseService = FirebaseRealtimeService()
        } else {
            Log.rooms.info("Firebase unavailable — using mock service")
            self.firebaseService = MockFirebaseService()
        }
    }

    // MARK: - Path Helpers

    private func usersPath(_ roomID: String) -> String {
        "rooms/\(roomID.firebaseSafe())/users"
    }

    private func userPath(_ roomID: String, _ userID: String) -> String {
        "rooms/\(roomID.firebaseSafe())/users/\(userID.firebaseSafe())"
    }

    private func metadataPath(_ roomID: String) -> String {
        "rooms/\(roomID.firebaseSafe())/metadata"
    }

    // MARK: - RoomRepository

    func joinRoom(roomID: String, participant: RoomParticipant) async throws {
        let path = userPath(roomID, participant.id)

        // Write participant entry
        try await firebaseService.write(path: path, value: participant.firebaseDictionary)

        // Set onDisconnect auto-cleanup (only for real Firebase)
        if let realService = firebaseService as? FirebaseRealtimeService {
            realService.setOnDisconnectRemove(path: path)
        }

        Log.rooms.info("Joined room \(roomID) as \(participant.username)")
    }

    func leaveRoom(roomID: String, userID: String) async throws {
        let path = userPath(roomID, userID)

        // Cancel onDisconnect before manual removal
        if let realService = firebaseService as? FirebaseRealtimeService {
            realService.cancelOnDisconnect(path: path)
        }

        try await firebaseService.remove(path: path)
        Log.rooms.info("Left room \(roomID)")
    }

    func updateHeartRate(roomID: String, userID: String, data: HeartRateData, username: String, color: String) async throws {
        let path = userPath(roomID, userID)
        var value = data.firebaseDictionary
        value["username"] = username
        value["color"] = color
        try await firebaseService.write(path: path, value: value)
    }

    func observeParticipants(roomID: String) -> AsyncStream<[RoomParticipant]> {
        let path = usersPath(roomID)

        return AsyncStream { continuation in
            let task = Task {
                for await snapshot in firebaseService.observe(path: path) {
                    let participants = Self.parseParticipants(from: snapshot)
                    continuation.yield(participants)
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Parsing

    private static func parseParticipants(from snapshot: [String: Any]) -> [RoomParticipant] {
        snapshot.compactMap { userID, value in
            guard let dict = value as? [String: Any] else { return nil }
            return RoomParticipant(id: userID, from: dict)
        }
    }
}
