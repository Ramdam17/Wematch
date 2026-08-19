import Foundation

/// `nonisolated`: a pure value type with no UI in it. The project sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise bind this — and
/// the computation it carries — to the main actor for no reason (plan 1.10).
nonisolated struct UsernameGenerator: Sendable {

    private let adjectives: [String]
    private let animals: [String]

    init() {
        self.adjectives = Self.loadDictionary(named: "Adjectives")
        self.animals = Self.loadDictionary(named: "Animals")
    }

    func generate() -> String {
        let adjective = adjectives.randomElement() ?? "happy"
        let animal = animals.randomElement() ?? "panda"
        let number = Int.random(in: 0...9999)
        return "\(adjective)_\(animal)\(String(format: "%04d", number))"
    }

    var adjectiveCount: Int { adjectives.count }
    var animalCount: Int { animals.count }

    private static func loadDictionary(named name: String) -> [String] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([String].self, from: data) else {
            fatalError("Failed to load \(name).json from bundle")
        }
        return words
    }
}
