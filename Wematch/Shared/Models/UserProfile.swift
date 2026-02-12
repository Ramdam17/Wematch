import Foundation

struct UserProfile: Identifiable, Sendable {
    let id: String
    var username: String
    var displayName: String?
    let createdAt: Date
    var usernameEdited: Bool
}
