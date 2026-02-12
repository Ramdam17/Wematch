import CloudKit
import OSLog

final class CloudKitManager: @unchecked Sendable {
    static let shared = CloudKitManager()

    let container: CKContainer
    let publicDatabase: CKDatabase

    private init() {
        let container = CKContainer(identifier: "iCloud.com.remyramadour.Wematch")
        self.container = container
        self.publicDatabase = container.publicCloudDatabase
        Log.cloudKit.info("CloudKit container initialized")
    }

    func verifyAccess() async throws {
        let status = try await container.accountStatus()
        Log.cloudKit.info("CloudKit account status: \(String(describing: status))")
    }
}
