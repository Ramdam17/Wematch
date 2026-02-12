import Foundation

struct Group: Identifiable, Sendable {
    let id: String
    var name: String
    let code: String
    let adminID: String
    var memberIDs: [String]
    let createdAt: Date
}
