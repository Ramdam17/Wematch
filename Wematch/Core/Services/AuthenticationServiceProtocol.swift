import Foundation

protocol AuthenticationServiceProtocol: Sendable {
    func signInWithApple() async throws -> String
    func signOut() async throws
    func deleteAccount() async throws
    var currentUserID: String? { get }
    var isAuthenticated: Bool { get }
}
