import Foundation
import OSLog

@Observable
@MainActor
final class SettingsViewModel {

    var isSigningOut = false
    var isDeletingAccount = false
    var showDeleteConfirmation = false
    var error: Error?

    private let authManager: AuthenticationManager
    private let deletionService: AccountDeletionService

    init(authManager: AuthenticationManager, deletionService: AccountDeletionService? = nil) {
        self.authManager = authManager
        self.deletionService = deletionService ?? AccountDeletionService()
    }

    var username: String {
        authManager.userProfile?.username ?? ""
    }

    var memberSince: String {
        guard let date = authManager.userProfile?.createdAt else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }

        authManager.signOut()
        Log.settings.info("User signed out")
    }

    func deleteAccount() async {
        guard let userID = authManager.currentUserID else { return }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await deletionService.deleteAllData(userID: userID)
            authManager.signOut()
            Log.settings.info("Account deleted and signed out")
        } catch {
            self.error = error
            Log.settings.error("Account deletion failed: \(error.localizedDescription)")
        }
    }
}
