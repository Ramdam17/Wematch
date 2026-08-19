import Foundation
import OSLog
import WematchCore

nonisolated final class FirebaseRoomRepository: RoomRepository, Sendable {

    private let firebaseService: any FirebaseServiceProtocol

    init(firebaseService: (any FirebaseServiceProtocol)? = nil) {
        if let firebaseService {
            self.firebaseService = firebaseService
        } else if FirebaseManager.shared.database != nil {
            self.firebaseService = FirebaseRealtimeService()
        } else {
            #if DEBUG
            // Development convenience only. In release this branch would hand the user
            // a room built entirely out of local state — a plot that looks alive and
            // shows nobody who exists (plan 1.7).
            Log.rooms.warning("Firebase unavailable — using in-memory mock (DEBUG builds only)")
            self.firebaseService = MockFirebaseService()
            #else
            Log.rooms.error("Firebase unavailable — every room operation will fail loudly")
            self.firebaseService = FirebaseRealtimeService(database: nil)
            #endif
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

        try await firebaseService.write(path: path, value: participant.firebaseDictionary)

        // Presence: the server reaps the node if this client vanishes. A join whose hook
        // did not arm throws — the entry exists, but it would outlive a crash, and the
        // user is better told than left a ghost on everyone's plot.
        try await firebaseService.armDisconnectRemoval(path: path)

        Log.rooms.info("Joined room \(roomID) as \(participant.username)")
    }

    func leaveRoom(roomID: String, userID: String) async throws {
        let path = userPath(roomID, userID)

        // Remove first, disarm second: a hook that outlives a successful removal only
        // deletes an absent node, whereas a failed disarm *before* the removal would have
        // skipped it and left the participant on the plot until the connection dropped.
        try await firebaseService.remove(path: path)
        try await firebaseService.disarmDisconnectRemoval(path: path)
        Log.rooms.info("Left room \(roomID)")
    }

    func updateHeartRate(roomID: String, userID: String, data: HeartRateData, username: String, slot: HeartPaletteSlot) async throws {
        let path = userPath(roomID, userID)
        var value: [String: any Sendable] = data.firebaseDictionary
        value["username"] = username
        value["colorSlot"] = slot.index
        try await firebaseService.write(path: path, value: value)
    }

    func observeConnection() -> AsyncStream<Bool> {
        firebaseService.observeConnection()
    }

    func observeParticipants(roomID: String) -> AsyncThrowingStream<[RoomParticipant], Error> {
        let path = usersPath(roomID)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await snapshot in firebaseService.observe(path: path) {
                        continuation.yield(Self.parseParticipants(from: snapshot.values))
                    }
                    continuation.finish()
                } catch {
                    // The room is gone as far as this device is concerned. Passed up
                    // rather than absorbed (plan 1.7, D2) — the caller shows it.
                    Log.rooms.error("Participant stream failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
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
