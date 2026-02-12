import Foundation

protocol UserProfileRepository: Sendable {
    func fetchProfile(userID: String) async throws -> UserProfile?
    func createProfile(_ profile: UserProfile) async throws
    func isUsernameAvailable(_ username: String) async throws -> Bool
}
