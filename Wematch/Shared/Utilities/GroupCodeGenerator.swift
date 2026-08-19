import Foundation

/// `nonisolated`: a pure value type with no UI in it. The project sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise bind this — and
/// the computation it carries — to the main actor for no reason (plan 1.10).
nonisolated struct GroupCodeGenerator: Sendable {

    // Exclude O/I to avoid confusion with 0/1
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let codeLength = 6

    static func generate() -> String {
        // `characters` is a non-empty constant, so randomElement() cannot return nil.
        // swiftlint:disable:next force_unwrapping
        String((0..<codeLength).map { _ in characters.randomElement()! })
    }
}
