import XCTest
import SwiftUI
@testable import Wematch

/// Pins the theme preference: its mapping onto the interface style, its persistence, and
/// the order the picker shows it in.
///
/// The mapping is the load-bearing part. Every colour token in the app resolves itself
/// through `UIColor(dynamicProvider:)` against the interface style, so if `.cosmic` ever
/// stopped meaning `.dark`, the entire Dark Cosmic theme would silently stop existing —
/// with nothing failing to build and nothing throwing.
@MainActor
final class ThemePreferenceTests: XCTestCase {

    // MARK: - Mapping

    func testColorSchemeMapping() {
        XCTAssertNil(
            ThemePreference.system.colorScheme,
            "system must force nothing — that is how it keeps following the device"
        )
        XCTAssertEqual(ThemePreference.pastel.colorScheme, .light)
        XCTAssertEqual(ThemePreference.cosmic.colorScheme, .dark)
    }

    func testEveryCaseHasADistinctLabelAndHint() {
        let labels = Set(ThemePreference.allCases.map(\.label))
        let hints = Set(ThemePreference.allCases.map(\.accessibilityHint))

        XCTAssertEqual(labels.count, ThemePreference.allCases.count)
        XCTAssertEqual(hints.count, ThemePreference.allCases.count)
        XCTAssertFalse(
            labels.contains(where: \.isEmpty),
            "an empty segment label would be an unreachable control for VoiceOver"
        )
    }

    /// The picker renders `allCases` in order, so declaration order is a design decision:
    /// the default sits first, then light before dark.
    func testCaseOrderIsTheControlOrder() {
        XCTAssertEqual(ThemePreference.allCases, [.system, .pastel, .cosmic])
    }

    // MARK: - UserDefaults store

    func testDefaultsToSystemWhenNothingStored() {
        let store = UserDefaultsThemePreferenceStore(defaults: makeDefaults())

        XCTAssertEqual(store.load(), .system)
    }

    func testRoundTripsEveryCase() {
        let defaults = makeDefaults()
        let store = UserDefaultsThemePreferenceStore(defaults: defaults)

        for preference in ThemePreference.allCases {
            store.save(preference)
            XCTAssertEqual(
                UserDefaultsThemePreferenceStore(defaults: defaults).load(),
                preference,
                "\(preference) did not survive a fresh store reading the same defaults"
            )
        }
    }

    func testUnknownStoredValueFallsBackToSystem() {
        let defaults = makeDefaults()
        defaults.set("aurora", forKey: "wematch.themePreference")

        XCTAssertEqual(
            UserDefaultsThemePreferenceStore(defaults: defaults).load(),
            .system,
            "a value from a build that knew more cases must degrade, not trap"
        )
    }

    // MARK: - Controller

    func testControllerAdoptsTheStoredPreferenceAtLaunch() {
        let controller = ThemeController(store: SpyThemePreferenceStore(initial: .cosmic))

        XCTAssertEqual(controller.preference, .cosmic)
        XCTAssertEqual(controller.preferredColorScheme, .dark)
    }

    func testSelectingPersistsAndPublishes() {
        let store = SpyThemePreferenceStore(initial: .system)
        let controller = ThemeController(store: store)

        controller.select(.pastel)

        XCTAssertEqual(controller.preference, .pastel)
        XCTAssertEqual(controller.preferredColorScheme, .light)
        XCTAssertEqual(store.saved, [.pastel])
    }

    func testSelectingTheCurrentPreferenceWritesNothing() {
        let store = SpyThemePreferenceStore(initial: .cosmic)
        let controller = ThemeController(store: store)

        controller.select(.cosmic)

        XCTAssertEqual(store.saved, [], "re-selecting the active theme must not touch the store")
    }

    // MARK: - Helpers

    /// A private suite per test, so nothing leaks into the simulator's real defaults or
    /// between tests running in the same process.
    private func makeDefaults(
        function: StaticString = #function
    ) -> UserDefaults {
        let name = "ThemePreferenceTests.\(function)"
        UserDefaults().removePersistentDomain(forName: name)
        guard let defaults = UserDefaults(suiteName: name) else {
            XCTFail("could not create a private defaults suite")
            return .standard
        }
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
}
