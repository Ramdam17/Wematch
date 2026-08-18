import Foundation

/// Which of the 20 heart hues a participant owns.
///
/// The slot is what travels between clients, not a resolved colour, so each client
/// renders the hue for its own colour mode: a vivid pastel on Dark Cosmic, a darkened
/// variant on Pastel Light — where the pastels measured 1.14–2.73:1 against the
/// background, well under the 3:1 floor for a graphical object.
struct HeartPaletteSlot: Hashable, Sendable {
    /// Number of hues in the palette. Slots wrap around it.
    static let count = 20

    let index: Int

    /// Wraps any integer into the palette range, so a malformed wire value degrades to
    /// a valid hue instead of trapping.
    init(index: Int) {
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
    init(userID: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in userID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        self.init(index: Int(hash % UInt64(Self.count)))
    }
}
