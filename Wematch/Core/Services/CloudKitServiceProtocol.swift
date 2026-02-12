import Foundation
import CloudKit

protocol CloudKitServiceProtocol: Sendable {
    func save(_ record: CKRecord) async throws -> CKRecord
    func fetch(recordType: CKRecord.RecordType, predicate: NSPredicate) async throws -> [CKRecord]
    func delete(recordID: CKRecord.ID) async throws
}
