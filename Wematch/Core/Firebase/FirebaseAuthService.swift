import Foundation
import FirebaseAuth
import FirebaseCore
import OSLog

/// Concrete FirebaseAuthenticating backed by FirebaseAuth.
/// Safe to instantiate before FirebaseApp.configure() — every member checks
/// configuration and fails loudly (never silently) when Firebase is absent.
struct FirebaseAuthService: FirebaseAuthenticating {

    var currentUID: String? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser?.uid
    }

    func signIn(withAppleIDToken idToken: String, rawNonce: String) async throws -> String {
        guard FirebaseApp.app() != nil else {
            Log.firebase.error("Firebase Auth sign-in attempted before configuration")
            throw FirebaseAuthError.notConfigured
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: nil
        )
        let result = try await Auth.auth().signIn(with: credential)
        Log.firebase.info("Firebase Auth federated sign-in OK (uid: \(result.user.uid))")
        return result.user.uid
    }

    func signOut() throws {
        guard FirebaseApp.app() != nil else { return }
        try Auth.auth().signOut()
        Log.firebase.info("Firebase Auth signed out")
    }
}
