import Foundation

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
    let color: String
    let timestamp: Date

    // MARK: - Firebase Serialization

    var firebaseDictionary: [String: Any] {
        [
            "username": username,
            "currentHR": currentHR,
            "previousHR": previousHR,
            "color": color,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }

    init(id: String, username: String, currentHR: Double = 0,
         previousHR: Double = 0, color: String, timestamp: Date = Date()) {
        self.id = id
        self.username = username
        self.currentHR = currentHR
        self.previousHR = previousHR
        self.color = color
        self.timestamp = timestamp
    }

    init?(id: String, from dictionary: [String: Any]) {
        guard let username = dictionary["username"] as? String else { return nil }
        self.id = id
        self.username = username
        self.currentHR = dictionary["currentHR"] as? Double ?? 0
        self.previousHR = dictionary["previousHR"] as? Double ?? 0
        self.color = dictionary["color"] as? String ?? "FF6B9D"
        self.timestamp = (dictionary["timestamp"] as? TimeInterval)
            .map { Date(timeIntervalSince1970: $0) } ?? Date()
    }
}
