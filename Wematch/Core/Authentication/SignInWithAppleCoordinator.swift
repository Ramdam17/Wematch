import AuthenticationServices
import CryptoKit
import OSLog
import Synchronization
import UIKit

enum AuthenticationError: LocalizedError {
    case missingCredential
    case canceled
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            "Unable to retrieve your Apple ID. Please try again."
        case .canceled:
            "Sign in was canceled."
        case .failed(let error):
            "Sign in failed: \(error.localizedDescription)"
        }
    }
}

/// Result of a Sign in with Apple flow, carrying what Firebase Auth federation
/// needs (identity token + the raw nonce that was hashed into the request).
struct AppleSignInResult: Sendable {
    let userID: String
    let identityToken: String
    let rawNonce: String
}

/// Not final: WematchTests subclasses this (via `@testable`) to stub `signIn()`.
///
/// **`@unchecked Sendable` justification** (plan 1.10). It is the *non-final* class that
/// forces it — a subclassable class cannot conform to `Sendable`, whatever its storage
/// looks like. The storage itself is no longer the reason: both fields moved behind a
/// mutex, so the pending continuation cannot be resumed twice or dropped by a delegate
/// callback racing the caller. `AuthorizationServices` does not document which thread it
/// calls back on, and this path has never run on a real device.
nonisolated class SignInWithAppleCoordinator: NSObject, @unchecked Sendable {

    /// The in-flight request: the continuation to resume, and the nonce Apple must echo.
    /// One `Mutex` for both because they are consumed together — resuming with the wrong
    /// nonce is worse than not resuming.
    private struct PendingRequest {
        var continuation: CheckedContinuation<AppleSignInResult, Error>?
        var rawNonce: String?
    }

    private let pending = Mutex(PendingRequest())

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in

            // Anti-replay nonce: raw value is sent to Firebase, its SHA-256
            // goes into the Apple request; Apple echoes it inside the identity
            // token, which Firebase verifies.
            let rawNonce = Self.randomNonceString()
            pending.withLock { $0 = PendingRequest(continuation: continuation, rawNonce: rawNonce) }

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = []
            request.nonce = Self.sha256(rawNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()

            Log.auth.info("Sign in with Apple request initiated")
        }
    }

    // MARK: - Nonce helpers (Apple's documented pattern)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension SignInWithAppleCoordinator: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        // Taken out under the lock and cleared in the same step, so a second callback
        // finds nothing to resume rather than resuming a continuation twice.
        let request = pending.withLock { pending -> PendingRequest in
            let taken = pending
            pending = PendingRequest()
            return taken
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8),
              let rawNonce = request.rawNonce else {
            Log.auth.error("Sign in with Apple: missing credential, identity token, or nonce")
            request.continuation?.resume(throwing: AuthenticationError.missingCredential)
            return
        }

        let userID = credential.user
        Log.auth.info("Sign in with Apple succeeded for user \(userID)")
        request.continuation?.resume(returning: AppleSignInResult(
            userID: userID,
            identityToken: identityToken,
            rawNonce: rawNonce
        ))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let request = pending.withLock { pending -> PendingRequest in
            let taken = pending
            pending = PendingRequest()
            return taken
        }

        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            Log.auth.info("Sign in with Apple canceled by user")
            request.continuation?.resume(throwing: AuthenticationError.canceled)
        } else {
            Log.auth.error("Sign in with Apple failed: \(error.localizedDescription)")
            request.continuation?.resume(throwing: AuthenticationError.failed(error))
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension SignInWithAppleCoordinator: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = scene.windows.first else {
            fatalError("No window scene available for sign-in presentation")
        }
        return window
    }
}
