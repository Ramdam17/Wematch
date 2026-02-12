import Foundation

protocol GroupRepository: Sendable {
    func fetchMyGroups() async throws -> [Group]
    func createGroup(name: String) async throws -> Group
    func deleteGroup(groupID: String) async throws
    func searchGroups(query: String) async throws -> [Group]
    func joinWithCode(_ code: String) async throws
}
