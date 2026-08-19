import SwiftUI

/// Which of the 20 heart hues a participant owns.
///
/// The slot is what travels between clients, not a resolved colour, so each client
/// renders the hue for its own colour mode: a vivid pastel on Dark Cosmic, a darkened
/// variant on Pastel Light — where the pastels measured 1.14–2.73:1 against the
/// background, well under the 3:1 floor for a graphical object.
public struct HeartPaletteSlot: Hashable, Sendable {
    /// Number of hues in the palette. Slots wrap around it.
    public static let count = 20

    public let index: Int

    /// Wraps any integer into the palette range, so a malformed wire value degrades to
    /// a valid hue instead of trapping.
    public init(index: Int) {
        let wrapped = index % Self.count
        self.index = wrapped < 0 ? wrapped + Self.count : wrapped
    }

    /// Derives a participant's slot from their user ID.
    ///
    /// Deliberately not `hashValue`: Swift seeds `Hasher` randomly per process, so the
    /// same user drew a different hue on every launch, and two devices never agreed on
    /// each other's colours — which is why a resolved hex had to be sent over the wire
    /// in the first place. FNV-1a over the UTF-8 bytes is stable across processes,
    /// devices and OS versions, so every client derives the same slot for the same ID.
    ///
    /// The Watch used to carry its own transcription of this hash, under a comment asking
    /// whoever changed one to change the other. Both devices now run these lines
    /// (plan 1.11).
    public init(userID: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in userID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        self.init(index: Int(hash % UInt64(Self.count)))
    }
}

/// The twenty hues themselves.
public enum HeartPalette {

    /// One palette for both colour modes: the marker's outline, not its fill, carries the
    /// contrast against the background.
    ///
    /// Derived rather than picked by hand. Twenty hues sit on an even 18° grid anchored on
    /// the brand pink, and each slot's lightness and saturation were searched to maximise
    /// the minimum CIEDE2000 distance across the whole set. A participant is tracked by
    /// colour as their heart moves across the plot, so two slots sharing a hue is a
    /// functional defect, not a cosmetic one — and the original twenty clustered badly
    /// (four yellows, four greens, four purples) at dE 3.7.
    ///
    /// Measured: minimum pairwise distance dE 11.8, past the dE 10 mark where two colours
    /// read as different at a glance, and 3.29:1 against the Dark Cosmic backgrounds.
    ///
    /// Why one palette and not two. Darkening these to clear 3:1 on a near-white
    /// background was tried and rejected: it forces the yellow and orange slots to olive
    /// and brown — unavoidable, since yellow carries intrinsically high luminance — and it
    /// compresses the hue space so hard that separability saturates near dE 7.5 no matter
    /// how many slots are asked for. Letting `plotMarkerOutline` provide the boundary
    /// keeps the hues as designed in both modes.
    ///
    /// This array existed twice — `WematchTheme.heartColorHexes` and
    /// `WatchHeartPalette.hexes` — under a comment reading "must match exactly". The
    /// phone and the Watch draw the same room, so a slot that resolved to two hues was a
    /// participant the two screens disagreed about (plan 1.11).
    public static let hexes: [String] = [
        "D3698D", "FA4249", "EFBBA9",
        "FAAA42", "D5C66D", "DCFA42",
        "CFF8A0", "6EFA42", "79D87F",
        "B0E8C4", "42FABC", "5EF7F2",
        "42CAFA", "4A94F2", "425BFA",
        "B9B0E8", "9D6DD5", "E497FC",
        "FA42EF", "E8B0D4",
    ]

    public static let colors: [Color] = hexes.map { Color(hex: $0) }

    public static func color(for slot: HeartPaletteSlot) -> Color {
        colors[slot.index]
    }

    /// Convenience for the wire, where a slot is still a bare `Int`.
    public static func color(slot: Int) -> Color {
        colors[HeartPaletteSlot(index: slot).index]
    }
}
