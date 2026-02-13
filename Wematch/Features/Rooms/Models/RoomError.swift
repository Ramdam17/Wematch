import Foundation

enum RoomError: LocalizedError {
    case firebaseUnavailable
    case healthKitDenied
    case roomFull
    case alreadyInRoom
    case watchDisconnected
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            "Unable to connect to the room service. Please try again later."
        case .healthKitDenied:
            "Heart rate access is required to join a room. Please enable it in Settings."
        case .roomFull:
            "This room is full. Maximum 20 participants allowed."
        case .alreadyInRoom:
            "You are already in this room."
        case .watchDisconnected:
            "Apple Watch disconnected. You have been removed from the room."
        case .notAuthenticated:
            "Please sign in to join a room."
        }
    }
}
