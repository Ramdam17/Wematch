import Foundation
@testable import Wematch

/// In-memory `ThemePreferenceStoring` that also records every write.
///
/// The recording matters: "the controller persists the choice" and "the controller does
/// not rewrite a choice that has not changed" are different claims, and only the second
/// needs the log.
final class SpyThemePreferenceStore: ThemePreferenceStoring {

    private(set) var saved: [ThemePreference] = []
    private var stored: ThemePreference

    init(initial: ThemePreference = .system) {
        self.stored = initial
    }

    func load() -> ThemePreference {
        stored
    }

    func save(_ preference: ThemePreference) {
        stored = preference
        saved.append(preference)
    }
}
