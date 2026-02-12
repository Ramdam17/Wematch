import Foundation
import OSLog

enum AuthState: Sendable {
    case unknown
    case signedOut
    case needsUsername
    case signedIn
}

@Observable
@MainActor
final class AuthenticationManager {

    // MARK: - State

    private(set) var authState: AuthState = .unknown
    private(set) var userProfile: UserProfile?
    private(set) var generatedUsername: String = ""
    private(set) var isLoading = false
    var error: Error?

    var currentUserID: String? { storedUserID }

    // MARK: - Dependencies

    private let repository: any UserProfileRepository
    private let coordinator: SignInWithAppleCoordinator
    private let usernameGenerator: UsernameGenerator
    private var storedUserID: String?

    private static let keychainKey = "appleUserID"

    // MARK: - Init

    init(repository: any UserProfileRepository = CloudKitUserProfileRepository(),
         coordinator: SignInWithAppleCoordinator = SignInWithAppleCoordinator(),
         usernameGenerator: UsernameGenerator = UsernameGenerator()) {
        self.repository = repository
        self.coordinator = coordinator
        self.usernameGenerator = usernameGenerator
    }

    // MARK: - Session Restoration

    func restoreSession() async {
        guard let userID = KeychainService.retrieve(key: Self.keychainKey) else {
            Log.auth.info("No stored session found")
            authState = .signedOut
            return
        }

        storedUserID = userID
        Log.auth.info("Restoring session for user \(userID)")

        do {
            if let profile = try await repository.fetchProfile(userID: userID) {
                userProfile = profile
                authState = .signedIn
                Log.auth.info("Session restored — welcome back \(profile.username)")
            } else {
                generatedUsername = usernameGenerator.generate()
                authState = .needsUsername
                Log.auth.info("Session restored but no profile — needs username")
            }
        } catch {
            Log.auth.error("Failed to restore session: \(error.localizedDescription)")
            authState = .signedOut
        }
    }

    // MARK: - Sign In

    func signInWithApple() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userID = try await coordinator.signIn()
            storedUserID = userID
            try KeychainService.save(key: Self.keychainKey, value: userID)

            if let profile = try await repository.fetchProfile(userID: userID) {
                userProfile = profile
                authState = .signedIn
                Log.auth.info("Returning user signed in: \(profile.username)")
            } else {
                generatedUsername = usernameGenerator.generate()
                authState = .needsUsername
                Log.auth.info("New user — username selection needed")
            }
        } catch let authError as AuthenticationError where authError == .canceled {
            Log.auth.info("Sign in canceled")
        } catch {
            self.error = error
            Log.auth.error("Sign in failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Username

    func shuffleUsername() {
        generatedUsername = usernameGenerator.generate()
        Log.auth.debug("Shuffled username: \(self.generatedUsername)")
    }

    func confirmUsername() async {
        guard let userID = storedUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let isAvailable = try await repository.isUsernameAvailable(self.generatedUsername)

            guard isAvailable else {
                Log.auth.warning("Username '\(self.generatedUsername)' is taken")
                self.error = UsernameError.taken
                shuffleUsername()
                return
            }

            let profile = UserProfile(
                id: userID,
                username: self.generatedUsername,
                displayName: nil,
                createdAt: Date(),
                usernameEdited: false
            )

            try await repository.createProfile(profile)
            userProfile = profile
            authState = .signedIn
            Log.auth.info("Profile created with username '\(self.generatedUsername)'")
        } catch {
            self.error = error
            Log.auth.error("Failed to confirm username: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try KeychainService.delete(key: Self.keychainKey)
        } catch {
            Log.auth.error("Failed to clear keychain: \(error.localizedDescription)")
        }
        storedUserID = nil
        userProfile = nil
        generatedUsername = ""
        authState = .signedOut
        Log.auth.info("User signed out")
    }
}

// MARK: - AuthenticationError Equatable

extension AuthenticationError: Equatable {
    static func == (lhs: AuthenticationError, rhs: AuthenticationError) -> Bool {
        switch (lhs, rhs) {
        case (.missingCredential, .missingCredential), (.canceled, .canceled):
            true
        case (.failed, .failed):
            true
        default:
            false
        }
    }
}

// MARK: - Username Error

enum UsernameError: LocalizedError {
    case taken

    var errorDescription: String? {
        switch self {
        case .taken:
            "This username is already taken. A new one has been generated for you."
        }
    }
}
