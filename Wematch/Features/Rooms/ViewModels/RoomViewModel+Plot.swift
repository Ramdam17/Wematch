import Foundation

/// What the plot is drawn from. Split out of `RoomViewModel.swift` to keep that file
/// under the length limit — same convention as the dashboard and Watch extensions.
extension RoomViewModel {

    var otherParticipants: [RoomParticipant] {
        participants.filter { $0.id != currentUserID }
    }

    var participantCount: Int { participants.count }

    /// All participants for the 2D plot, including self and simulated users.
    var allParticipantsForPlot: [RoomParticipant] {
        var result = participants

        // Add self if not already in Firebase participants (edge case during join)
        // Note: Firebase stores IDs as firebaseSafe() (dots → underscores), so we must compare using the safe version
        if let userID = currentUserID {
            let safeUserID = userID.firebaseSafe()
            if !result.contains(where: { $0.id == safeUserID }), ownHeartRate > 0 {
                result.append(RoomParticipant(
                    id: safeUserID,
                    username: currentUsername,
                    currentHR: ownHeartRate,
                    previousHR: previousHeartRate,
                    slot: assignedSlot
                ))
            }
        }

        #if targetEnvironment(simulator)
        result.append(contentsOf: simulatedParticipants)
        #endif

        return result
    }

    /// Sync graph computed from current participants.
    var syncGraph: SyncGraph {
        SyncGraph(participants: allParticipantsForPlot)
    }
}
