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

    /// Canonical user identity for the whole app since plan 1.2: the Firebase
    /// Auth UID. Keys Firestore documents (users/{uid}, social graph) and all
    /// Realtime Database paths. nil = no usable session.
    var currentUserID: String? { firebaseUID }

    /// Apple user ID from Sign in with Apple — kept ONLY as the local session
    /// marker (Keychain) and for legacy CloudKit records until 1.2d completes.
    /// Never use it to key Firebase paths.
    var appleUserID: String? { storedUserID }

    private(set) var firebaseUID: String?

    // MARK: - Dependencies

    private let repository: any UserProfileRepository
    private let coordinator: SignInWithAppleCoordinator
    private let usernameGenerator: UsernameGenerator
    private let keychain: any KeychainStoring
    private let firebaseAuth: any FirebaseAuthenticating
    private var storedUserID: String?

    private static let keychainKey = "appleUserID"

    // MARK: - Init

    init(repository: (any UserProfileRepository)? = nil,
         coordinator: SignInWithAppleCoordinator? = nil,
         usernameGenerator: UsernameGenerator? = nil,
         keychain: (any KeychainStoring)? = nil,
         firebaseAuth: (any FirebaseAuthenticating)? = nil) {
        self.repository = repository ?? FirestoreUserProfileRepository()
        self.coordinator = coordinator ?? SignInWithAppleCoordinator()
        self.usernameGenerator = usernameGenerator ?? UsernameGenerator()
        self.keychain = keychain ?? KeychainService()
        self.firebaseAuth = firebaseAuth ?? FirebaseAuthService()
    }

    // MARK: - Session Restoration

    func restoreSession() async {
        guard let userID = keychain.retrieve(key: Self.keychainKey) else {
            Log.auth.info("No stored session found")
            authState = .signedOut
            return
        }

        storedUserID = userID
        Log.auth.info("Restoring session for user \(userID)")

        // Firebase Auth persists its own session; without it there is no
        // usable identity (profiles and paths are keyed by UID) — re-sign-in.
        firebaseUID = firebaseAuth.currentUID
        guard let uid = firebaseUID else {
            Log.auth.warning("Apple session found but no Firebase session — sign-in required again")
            authState = .signedOut
            return
        }

        do {
            if let profile = try await repository.fetchProfile(userID: uid) {
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
            let signIn = try await coordinator.signIn()
            storedUserID = signIn.userID
            try keychain.save(key: Self.keychainKey, value: signIn.userID)

            // Federate into Firebase Auth. Since plan 1.2 the Firebase UID IS
            // the app identity (Firestore + RTDB) — federation failure fails
            // the sign-in, loudly.
            let uid = try await firebaseAuth.signIn(
                withAppleIDToken: signIn.identityToken,
                rawNonce: signIn.rawNonce
            )
            firebaseUID = uid

            if let profile = try await repository.fetchProfile(userID: uid) {
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
        guard let userID = firebaseUID else { return }

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
            try keychain.delete(key: Self.keychainKey)
        } catch {
            Log.auth.error("Failed to clear keychain: \(error.localizedDescription)")
        }
        do {
            try firebaseAuth.signOut()
        } catch {
            Log.auth.error("Firebase sign-out failed: \(error.localizedDescription)")
        }
        firebaseUID = nil
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
