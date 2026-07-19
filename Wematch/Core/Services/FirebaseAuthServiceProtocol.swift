import Foundation

enum FirebaseAuthError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Real-time service is not configured. Rooms are unavailable."
        }
    }
}

/// Abstraction over Firebase Authentication so AuthenticationManager never
/// touches FirebaseAuth types directly (project rule: protocols at service
/// boundaries) and tests can inject an in-memory fake.
protocol FirebaseAuthenticating: Sendable {
    /// Firebase UID of the signed-in user, if a Firebase session exists.
    /// This UID — not the Apple user ID — keys all Realtime Database paths.
    var currentUID: String? { get }

    /// Federates a Sign in with Apple credential into Firebase Auth.
    /// Returns the Firebase UID.
    func signIn(withAppleIDToken idToken: String, rawNonce: String) async throws -> String

    func signOut() throws

    /// Permanently deletes the Firebase Auth account of the signed-in user.
    /// May throw requiresRecentLogin — surface it, never swallow.
    func deleteAccount() async throws
}
