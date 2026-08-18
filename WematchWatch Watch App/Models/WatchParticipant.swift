import Foundation

struct WatchParticipant: Identifiable, Sendable {
    let id: String
    var currentHR: Double
    var previousHR: Double
    /// Palette slot, resolved locally — the phone sends the slot, not a colour.
    let colorSlot: Int

    init(id: String, currentHR: Double, previousHR: Double, colorSlot: Int) {
        self.id = id
        self.currentHR = currentHR
        self.previousHR = previousHR
        self.colorSlot = WatchHeartPalette.wrap(colorSlot)
    }

    /// Initialize from a WatchConnectivity dictionary sent by iPhone.
    init?(from dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String else { return nil }
        self.id = id
        self.currentHR = dictionary["currentHR"] as? Double ?? 0
        self.previousHR = dictionary["previousHR"] as? Double ?? 0
        // A payload without a slot only comes from a phone build predating it; deriving
        // it from the ID lands on the same hue the phone would have sent.
        self.colorSlot = (dictionary["colorSlot"] as? Int).map(WatchHeartPalette.wrap)
            ?? WatchHeartPalette.slot(forUserID: id)
    }
}

/// Pre-computed room state received from iPhone.
struct WatchRoomUpdate: Sendable {
    let participants: [WatchParticipant]
    let currentUserID: String
    let maxChain: Int
    let syncedCount: Int
    let newSyncFormations: Bool

    init?(from message: [String: Any]) {
        guard let participantDicts = message["participants"] as? [[String: Any]] else { return nil }
        self.participants = participantDicts.compactMap { WatchParticipant(from: $0) }
        self.currentUserID = message["currentUserID"] as? String ?? ""
        self.maxChain = message["maxChain"] as? Int ?? 0
        self.syncedCount = message["syncedCount"] as? Int ?? 0
        self.newSyncFormations = message["newSyncFormations"] as? Bool ?? false
    }
}
