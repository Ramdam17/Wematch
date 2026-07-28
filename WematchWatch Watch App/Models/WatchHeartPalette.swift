import SwiftUI

/// Watch-side resolution of the heart palette slots the iPhone sends.
///
/// Duplicated rather than shared because `WematchShared` is iOS-only, the same reason
/// `WatchBezierPath` and `WatchPlotCoordinates` exist. Only the Dark Cosmic hues are
/// carried: watchOS has no light appearance, so the light variants would never resolve.
enum WatchHeartPalette {
    // The project sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, but slot arithmetic
    // has to run from WatchParticipant's nonisolated decoding init, so the pure integer
    // members opt out. `colors` stays isolated: only views read it.
    nonisolated static let count = 20

    // Must match WematchTheme.heartColorHexes exactly: the phone and the watch draw the
    // same room, so a slot has to be the same hue on both.
    private static let hexes: [String] = [
        "D3698D", "FA4249", "EFBBA9",
        "FAAA42", "D5C66D", "DCFA42",
        "CFF8A0", "6EFA42", "79D87F",
        "B0E8C4", "42FABC", "5EF7F2",
        "42CAFA", "4A94F2", "425BFA",
        "B9B0E8", "9D6DD5", "E497FC",
        "FA42EF", "E8B0D4",
    ]

    static let colors: [Color] = hexes.map { Color(hex: $0) }

    static func color(slot: Int) -> Color {
        colors[wrap(slot)]
    }

    /// Wraps any integer into the palette range so a malformed payload degrades to a
    /// valid hue instead of trapping.
    nonisolated static func wrap(_ slot: Int) -> Int {
        let wrapped = slot % count
        return wrapped < 0 ? wrapped + count : wrapped
    }

    /// Mirrors `HeartPaletteSlot(userID:)` on iOS — FNV-1a over the UTF-8 bytes — so a
    /// payload arriving without a slot lands on the hue the phone would have chosen.
    /// The expected values are pinned by `HeartPaletteSlotTests` in the iOS test target,
    /// which cannot reach this target: keep the two implementations in sync by hand.
    nonisolated static func slot(forUserID userID: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in userID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return Int(hash % UInt64(count))
    }
}
