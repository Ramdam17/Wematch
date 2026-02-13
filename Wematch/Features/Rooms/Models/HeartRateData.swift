import Foundation

struct HeartRateData: Codable, Sendable, Equatable {
    let currentHR: Double
    let previousHR: Double
    let timestamp: Date

    init(currentHR: Double, previousHR: Double, timestamp: Date = Date()) {
        self.currentHR = currentHR
        self.previousHR = previousHR
        self.timestamp = timestamp
    }

    // MARK: - Firebase Serialization

    var firebaseDictionary: [String: Any] {
        [
            "currentHR": currentHR,
            "previousHR": previousHR,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }

    init?(from dictionary: [String: Any]) {
        guard let currentHR = dictionary["currentHR"] as? Double,
              let previousHR = dictionary["previousHR"] as? Double,
              let timestamp = dictionary["timestamp"] as? TimeInterval else {
            return nil
        }
        self.currentHR = currentHR
        self.previousHR = previousHR
        self.timestamp = Date(timeIntervalSince1970: timestamp)
    }
}
