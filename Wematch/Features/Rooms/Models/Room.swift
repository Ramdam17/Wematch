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
}
