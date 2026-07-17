import Foundation
@testable import Wematch

/// In-memory FirebaseAuthenticating for tests — no Firebase SDK involved.
final class MockFirebaseAuthService: FirebaseAuthenticating, @unchecked Sendable {
    // Test-only: single-threaded XCTest access.
    var uid: String?
    var uidToReturn = "firebase_uid_mock"
    var shouldThrow = false
    var signOutCount = 0

    var currentUID: String? { uid }

    func signIn(withAppleIDToken idToken: String, rawNonce: String) async throws -> String {
        if shouldThrow { throw FirebaseAuthError.notConfigured }
        uid = uidToReturn
        return uidToReturn
    }

    func signOut() throws {
        signOutCount += 1
        uid = nil
    }
}
