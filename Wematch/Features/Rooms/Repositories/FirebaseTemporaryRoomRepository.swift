import Foundation
import OSLog

final class FirebaseTemporaryRoomRepository: TemporaryRoomRepository, @unchecked Sendable {

    private let firebaseService: any FirebaseServiceProtocol

    init(firebaseService: (any FirebaseServiceProtocol)? = nil) {
        if let firebaseService {
            self.firebaseService = firebaseService
        } else if FirebaseManager.shared.database != nil {
            self.firebaseService = FirebaseRealtimeService()
        } else {
            Log.rooms.info("Firebase unavailable — using mock service for temp rooms")
            self.firebaseService = MockFirebaseService()
        }
    }

    // MARK: - Path Helpers

    private func indexPath(_ userID: String, _ roomID: String) -> String {
        "tempRooms/\(userID.firebaseSafe())/\(roomID.firebaseSafe())"
    }

    private func userIndexPath(_ userID: String) -> String {
        "tempRooms/\(userID.firebaseSafe())"
    }

    private func roomUsersPath(_ roomID: String) -> String {
        "rooms/\(roomID.firebaseSafe())/users"
    }

    // MARK: - TemporaryRoomRepository

    func createRoom(roomID: String, userA: String, userB: String,
                    userAUsername: String, userBUsername: String) async throws {
        let now = Date().timeIntervalSince1970

        // Member IDs live in the room's metadata — the ONLY source cleanup
        // reads from (never parsed out of the roomID, audit E1). Stored raw:
        // they are Firebase UIDs used as values, not path keys.
        try await firebaseService.write(
            path: "rooms/\(roomID.firebaseSafe())/metadata",
            value: [
                "type": "temporary",
                "memberIDs": [userA, userB],
                "createdAt": now
            ]
        )

        // Write index entry for User A (friend = B)
        try await firebaseService.write(
            path: indexPath(userA, roomID),
            value: [
                "friendID": userB,
                "friendUsername": userBUsername,
                "createdAt": now
            ]
        )

        // Write index entry for User B (friend = A)
        try await firebaseService.write(
            path: indexPath(userB, roomID),
            value: [
                "friendID": userA,
                "friendUsername": userAUsername,
                "createdAt": now
            ]
        )

        Log.rooms.info("Created temp room index: \(roomID)")
    }

    func fetchActiveRooms(userID: String) async throws -> [TemporaryRoom] {
        // Read the user's temp room index
        // observe() returns an AsyncStream — we take the first snapshot
        let path = userIndexPath(userID)

        return await withCheckedContinuation { continuation in
            let task = Task {
                var result: [TemporaryRoom] = []
                for await snapshot in firebaseService.observe(path: path) {
                    result = Self.parseRooms(from: snapshot)
                    break // Take only the first snapshot
                }
                continuation.resume(returning: result)
            }

            // Safety: cancel after 5 seconds if no response
            Task {
                try? await Task.sleep(for: .seconds(5))
                task.cancel()
            }
        }
    }

    func deleteRoom(roomID: String) async throws {
        // Resolve members from metadata — never from the roomID string (E1).
        let metadata = await readOnce(path: "rooms/\(roomID.firebaseSafe())/metadata")
        if let memberIDs = metadata["memberIDs"] as? [String] {
            for memberID in memberIDs {
                try await firebaseService.remove(path: indexPath(memberID, roomID))
            }
        } else {
            // Legacy room without metadata: the room node is still removable,
            // but its index entries cannot be resolved — loud, not silent.
            Log.rooms.error("Temp room \(roomID) has no memberIDs metadata — index entries left behind")
        }

        // Remove room data from Firebase
        try await firebaseService.remove(path: "rooms/\(roomID.firebaseSafe())")

        Log.rooms.info("Destroyed temp room: \(roomID)")
    }

    /// One-shot read built on the observe stream (first snapshot wins,
    /// 5 s safety timeout). Single home for the pattern until a proper
    /// `read(path:)` lands on FirebaseServiceProtocol (plan 1.7, C5).
    private func readOnce(path: String) async -> [String: Any] {
        await withCheckedContinuation { continuation in
            let task = Task {
                for await snapshot in firebaseService.observe(path: path) {
                    continuation.resume(returning: snapshot)
                    return
                }
                continuation.resume(returning: [:])
            }

            Task {
                try? await Task.sleep(for: .seconds(5))
                task.cancel()
            }
        }
    }

    func hasParticipants(roomID: String) async throws -> Bool {
        let path = roomUsersPath(roomID)

        return await withCheckedContinuation { continuation in
            let task = Task {
                for await snapshot in firebaseService.observe(path: path) {
                    continuation.resume(returning: !snapshot.isEmpty)
                    return
                }
                continuation.resume(returning: false)
            }

            Task {
                try? await Task.sleep(for: .seconds(5))
                task.cancel()
            }
        }
    }

    // MARK: - Parsing

    private static func parseRooms(from snapshot: [String: Any]) -> [TemporaryRoom] {
        snapshot.compactMap { roomID, value in
            guard let dict = value as? [String: Any],
                  let friendID = dict["friendID"] as? String,
                  let friendUsername = dict["friendUsername"] as? String else {
                return nil
            }

            let createdAt: Date
            if let timestamp = dict["createdAt"] as? TimeInterval {
                createdAt = Date(timeIntervalSince1970: timestamp)
            } else {
                createdAt = Date()
            }

            return TemporaryRoom(
                id: roomID,
                friendID: friendID,
                friendUsername: friendUsername,
                createdAt: createdAt
            )
        }
    }
}
