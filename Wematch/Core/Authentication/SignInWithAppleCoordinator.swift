import AuthenticationServices
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

final class SignInWithAppleCoordinator: NSObject, @unchecked Sendable {

    private var continuation: CheckedContinuation<String, Error>?

    func signIn() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = []

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()

            Log.auth.info("Sign in with Apple request initiated")
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension SignInWithAppleCoordinator: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Log.auth.error("Sign in with Apple: missing credential")
            continuation?.resume(throwing: AuthenticationError.missingCredential)
            continuation = nil
            return
        }

        let userID = credential.user
        Log.auth.info("Sign in with Apple succeeded for user \(userID)")
        continuation?.resume(returning: userID)
        continuation = nil
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
