import Foundation

enum WatchMessageType: String, Codable, Sendable {
    case heartRate
    case enterRoom
    case exitRoom
}

enum WatchMessage: Sendable {

    // MARK: - Factory

    static func heartRate(_ hr: Double, timestamp: Date = Date()) -> [String: Any] {
        [
            "type": WatchMessageType.heartRate.rawValue,
            "hr": hr,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }

    static func enterRoom(roomID: String) -> [String: Any] {
        [
            "type": WatchMessageType.enterRoom.rawValue,
            "roomID": roomID
        ]
    }

    static func exitRoom() -> [String: Any] {
        [
            "type": WatchMessageType.exitRoom.rawValue
        ]
    }

    // MARK: - Parsing

    static func type(from dictionary: [String: Any]) -> WatchMessageType? {
        guard let rawType = dictionary["type"] as? String else { return nil }
        return WatchMessageType(rawValue: rawType)
    }

    static func heartRateValue(from dictionary: [String: Any]) -> Double? {
        dictionary["hr"] as? Double
    }

    static func roomID(from dictionary: [String: Any]) -> String? {
        dictionary["roomID"] as? String
    }
}
