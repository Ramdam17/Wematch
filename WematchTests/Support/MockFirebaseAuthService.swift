import Foundation
@testable import Wematch

/// In-memory FirebaseAuthenticating for tests — no Firebase SDK involved.
/// `@unchecked Sendable` justification: test-only. The stored state is written and
/// read from the main actor inside a single test method, and no instance outlives
/// the test that made it (plan 1.10).
final class MockFirebaseAuthService: FirebaseAuthenticating, @unchecked Sendable {
    // Test-only: single-threaded XCTest access.
    var uid: String?
    var uidToReturn = "firebase_uid_mock"
    var shouldThrow = false
    var signOutCount = 0
    var deleteAccountCount = 0

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

    func deleteAccount() async throws {
        deleteAccountCount += 1
        uid = nil
    }
}
