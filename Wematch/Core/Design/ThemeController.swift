import SwiftUI
import OSLog

/// Owns the app's appearance choice for the lifetime of the process.
///
/// It sits above the tab tree rather than inside `SettingsViewModel` because the value is
/// read at the root — `WematchApp` hands `preferredColorScheme` to the window — and
/// written from a leaf. A ViewModel scoped to the Settings screen is rebuilt every time
/// that screen appears, so the root would have nothing durable to read.
@Observable
@MainActor
final class ThemeController {

    private(set) var preference: ThemePreference

    private let store: any ThemePreferenceStoring

    init(store: (any ThemePreferenceStoring)? = nil) {
        let store = store ?? UserDefaultsThemePreferenceStore()
        self.store = store
        self.preference = store.load()
    }

    /// What the app root hands to `preferredColorScheme`; `nil` means "force nothing",
    /// which is how `.system` keeps following the phone.
    ///
    /// Every colour token resolves through `UIColor(dynamicProvider:)`, which reads the
    /// trait collection rather than SwiftUI's environment — so this only works if
    /// `preferredColorScheme` propagates all the way to the window. Verified on the
    /// simulator in all three directions: a light phone forced to `.cosmic` renders dark
    /// (status-bar glyphs included, which is the tell that the traits flipped, not just
    /// the environment), a dark phone forced to `.pastel` renders light, and `.system`
    /// on a dark phone stays dark. Xcode Previews cannot show this — its Color Scheme
    /// variant is applied above the preview content and wins.
    var preferredColorScheme: ColorScheme? {
        preference.colorScheme
    }

    func select(_ preference: ThemePreference) {
        guard preference != self.preference else { return }

        self.preference = preference
        store.save(preference)
        Log.settings.info("Theme preference set to \(preference.rawValue, privacy: .public)")
    }
}
