import AuthenticationServices
import CryptoKit
import OSLog
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

// Not final: WematchTests subclasses this (via @testable) to stub signIn().
class SignInWithAppleCoordinator: NSObject, @unchecked Sendable {

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentRawNonce: String?

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // Anti-replay nonce: raw value is sent to Firebase, its SHA-256
            // goes into the Apple request; Apple echoes it inside the identity
            // token, which Firebase verifies.
            let rawNonce = Self.randomNonceString()
            self.currentRawNonce = rawNonce

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
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8),
              let rawNonce = currentRawNonce else {
            Log.auth.error("Sign in with Apple: missing credential, identity token, or nonce")
            continuation?.resume(throwing: AuthenticationError.missingCredential)
            continuation = nil
            currentRawNonce = nil
            return
        }

        let userID = credential.user
        Log.auth.info("Sign in with Apple succeeded for user \(userID)")
        continuation?.resume(returning: AppleSignInResult(
            userID: userID,
            identityToken: identityToken,
            rawNonce: rawNonce
        ))
        continuation = nil
        currentRawNonce = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            Log.auth.info("Sign in with Apple canceled by user")
            continuation?.resume(throwing: AuthenticationError.canceled)
        } else {
            Log.auth.error("Sign in with Apple failed: \(error.localizedDescription)")
            continuation?.resume(throwing: AuthenticationError.failed(error))
        }
        continuation = nil
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
