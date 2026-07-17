import Foundation
import FirebaseCore
import FirebaseFirestore
import OSLog

/// Firestore-backed user profiles (plan 1.2b) — replaces CloudKitUserProfileRepository
/// as the identity source. Documents live at `users/{firebaseUID}`; username uniqueness
/// is enforced by reservation documents at `usernames/{username}` created in the same
/// batch (security rules deny overwriting someone else's reservation, so a lost race
/// fails the whole batch — surfaced as `UsernameError.taken`).
struct FirestoreUserProfileRepository: UserProfileRepository {

    private var database: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }

    // MARK: - UserProfileRepository

    func fetchProfile(userID: String) async throws -> UserProfile? {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await database.collection("users").document(userID).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return UserProfile(
            id: userID,
            username: data["username"] as? String ?? "",
            displayName: data["displayName"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            usernameEdited: data["usernameEdited"] as? Bool ?? false
        )
    }

    func createProfile(_ profile: UserProfile) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }

        let batch = database.batch()
        let profileRef = database.collection("users").document(profile.id)
        let usernameRef = database.collection("usernames").document(profile.username)

        var fields: [String: Any] = [
            "username": profile.username,
            "createdAt": Timestamp(date: profile.createdAt),
            "usernameEdited": profile.usernameEdited
        ]
        if let displayName = profile.displayName {
            fields["displayName"] = displayName
        }
        batch.setData(fields, forDocument: profileRef)
        batch.setData(["uid": profile.id], forDocument: usernameRef)

        do {
            try await batch.commit()
            Log.firebase.info("Profile created for uid \(profile.id)")
        } catch {
            // A denied write on the reservation doc means the username is held
            // by someone else (rules forbid overwriting a foreign reservation).
            if isPermissionDenied(error) {
                Log.firebase.warning("Username '\(profile.username)' reservation lost: \(error.localizedDescription)")
                throw UsernameError.taken
            }
            Log.firebase.error("Profile creation failed: \(error.localizedDescription)")
            throw error
        }
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        guard let database else { throw FirebaseAuthError.notConfigured }
        let snapshot = try await database.collection("usernames").document(username).getDocument()
        return !snapshot.exists
    }

    func deleteProfile(userID: String) async throws {
        guard let database else { throw FirebaseAuthError.notConfigured }

        // Fetch first: the username reservation must be released with the profile.
        let profile = try await fetchProfile(userID: userID)

        let batch = database.batch()
        batch.deleteDocument(database.collection("users").document(userID))
        if let username = profile?.username, !username.isEmpty {
            batch.deleteDocument(database.collection("usernames").document(username))
        }
        try await batch.commit()
        Log.firebase.info("Profile deleted for uid \(userID)")
    }

    // MARK: - Helpers

    private func isPermissionDenied(_ error: Error) -> Bool {
        (error as NSError).domain == FirestoreErrorDomain
            && (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue
    }
}
