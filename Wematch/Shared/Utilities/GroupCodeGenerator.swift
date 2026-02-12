import Foundation

struct GroupCodeGenerator: Sendable {

    // Exclude O/I to avoid confusion with 0/1
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let codeLength = 6

    static func generate() -> String {
        String((0..<codeLength).map { _ in characters.randomElement()! })
    }
}
