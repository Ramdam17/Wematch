import Foundation
import WematchCore

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
        self.colorSlot = HeartPaletteSlot(index: colorSlot).index
    }

    /// From what the iPhone sent (plan 1.10).
    ///
    /// It used to be `init?(from dictionary: [String: Any])`, where every field was an
    /// `as? Double ?? 0`: a renamed key put a heart at 0 BPM on the plot instead of
    /// failing. `WatchMessage.RoomUpdate.Participant` is decoded once, or not at all.
    init(_ participant: WatchMessage.RoomUpdate.Participant) {
        self.init(
            id: participant.id,
            currentHR: participant.currentHR,
            previousHR: participant.previousHR,
            colorSlot: participant.colorSlot
        )
    }
}
