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

        // Write index entry for User A (friend = B)
        try await firebaseService.write(
            path: indexPath(userA, roomID),
            value: [
                "friendID": userB.firebaseSafe(),
                "friendUsername": userBUsername,
                "createdAt": now
            ]
        )

        // Write index entry for User B (friend = A)
        try await firebaseService.write(
            path: indexPath(userB, roomID),
            value: [
                "friendID": userA.firebaseSafe(),
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

    func deleteRoom(roomID: String, userA: String, userB: String) async throws {
        // Remove index entries for both users
        try await firebaseService.remove(path: indexPath(userA, roomID))
        try await firebaseService.remove(path: indexPath(userB, roomID))

        // Remove room data from Firebase
        try await firebaseService.remove(path: "rooms/\(roomID.firebaseSafe())")

        Log.rooms.info("Destroyed temp room: \(roomID)")
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
