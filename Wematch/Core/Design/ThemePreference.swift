import SwiftUI
import OSLog

/// Which of the two Wematch looks the app wears — or neither, deferring to the phone.
///
/// Pastel Light and Dark Cosmic are named art directions rather than "light mode" and
/// "dark mode", but they map onto the system interface style one-to-one. That mapping is
/// the whole reason every token can resolve itself through `UIColor(dynamicProvider:)`
/// instead of being switched by hand somewhere in a view.
///
/// Three cases, not two. The Figma comp draws a two-segment pill, but the validated
/// design brief (2026-07-19) specifies "a theme toggle lands in Settings (persisted;
/// follows-system as third option)". Without `system` the app would have to guess an
/// initial look and then never follow the phone again.
enum ThemePreference: String, CaseIterable, Sendable {
    /// Follow the device's appearance setting. The default until someone chooses.
    case system
    /// Pastel Light — the canonical theme.
    case pastel
    /// Dark Cosmic.
    case cosmic

    /// The scheme to force on the app, or `nil` to inherit the device's.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .pastel: .light
        case .cosmic: .dark
        }
    }

    var label: String {
        switch self {
        case .system: "System"
        case .pastel: "Pastel"
        case .cosmic: "Cosmic"
        }
    }

    /// Spoken to VoiceOver, where "Pastel" and "Cosmic" are brand names that say nothing
    /// about what picking them does.
    var accessibilityHint: String {
        switch self {
        case .system: "Follows your device appearance setting"
        case .pastel: "The light theme"
        case .cosmic: "The dark theme"
        }
    }
}

// MARK: - Persistence

/// Where the choice is kept.
///
/// A protocol so nothing above it reaches for `UserDefaults.standard` directly, and so
/// the tests can pin the load/save contract without touching the real defaults — which
/// would leak between test runs and between tests and the simulator.
protocol ThemePreferenceStoring {
    func load() -> ThemePreference
    func save(_ preference: ThemePreference)
}

struct UserDefaultsThemePreferenceStore: ThemePreferenceStoring {

    /// Namespaced because this is the first thing the app has ever put in defaults;
    /// a bare `"theme"` would be a poor precedent for everything that follows.
    private static let key = "wematch.themePreference"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ThemePreference {
        guard let raw = defaults.string(forKey: Self.key) else { return .system }

        guard let preference = ThemePreference(rawValue: raw) else {
            // Written by a build that knew a case this one doesn't. Falling back to the
            // system appearance is the right recovery, but doing it silently would hide
            // a botched downgrade behind "the theme keeps resetting".
            Log.settings.error("Unknown stored theme preference '\(raw, privacy: .public)' — falling back to system")
            return .system
        }

        return preference
    }

    func save(_ preference: ThemePreference) {
        defaults.set(preference.rawValue, forKey: Self.key)
    }
}
