import Foundation
import os

struct Room: Identifiable, Sendable {
    let id: String
    let type: RoomType
    var participants: [RoomParticipant]
    let createdAt: Date
}

enum RoomType: String, Sendable {
    case group
    case temporary
}

struct RoomParticipant: Identifiable, Sendable {
    let id: String
    let username: String
    var currentHR: Double
    var previousHR: Double
    /// Palette slot, not a resolved colour: every client renders it for its own mode.
    let slot: HeartPaletteSlot
    let timestamp: Date

    // MARK: - Firebase Serialization

    var firebaseDictionary: [String: Any] {
        [
            "username": username,
            "currentHR": currentHR,
            "previousHR": previousHR,
            "colorSlot": slot.index,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }

    init(id: String, username: String, currentHR: Double = 0,
         previousHR: Double = 0, slot: HeartPaletteSlot, timestamp: Date = Date()) {
        self.id = id
        self.username = username
        self.currentHR = currentHR
        self.previousHR = previousHR
        self.slot = slot
        self.timestamp = timestamp
    }

    init?(id: String, from dictionary: [String: Any]) {
        guard let username = dictionary["username"] as? String else { return nil }
        self.id = id
        self.username = username
        self.currentHR = dictionary["currentHR"] as? Double ?? 0
        self.previousHR = dictionary["previousHR"] as? Double ?? 0
        self.timestamp = (dictionary["timestamp"] as? TimeInterval)
            .map { Date(timeIntervalSince1970: $0) } ?? Date()

        // Absent only in data written before the slot replaced the hex. Deriving the
        // slot from the ID lands on the same hue every client would have chosen, so a
        // stale record degrades to the right colour rather than a placeholder pink.
        if let slotValue = dictionary["colorSlot"] as? Int {
            self.slot = HeartPaletteSlot(index: slotValue)
        } else {
            self.slot = HeartPaletteSlot(userID: id)
            Log.rooms.debug("Participant \(id, privacy: .private) carries no colorSlot; derived locally")
        }
    }
}
