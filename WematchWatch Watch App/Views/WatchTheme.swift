import SwiftUI

/// The handful of tokens the Watch screens need.
///
/// Only the Dark Cosmic values exist: watchOS has no light appearance, so the pairs the
/// iPhone's `WematchTheme` carries would resolve to the same branch every time. The
/// background is true black rather than `bg/0` — on an OLED watch face that is the
/// difference between a screen that disappears into the bezel and one that does not.
enum WatchTheme {
    static let background = Color.black

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "9CA3AF")
    /// `white/a60` — the Idle screen's explanatory line.
    static let textTertiary = Color.white.opacity(0.6)

    /// `glass/fill`, Dark Cosmic: white at 15% over black.
    static let glassFill = Color.white.opacity(0.15)

    /// The brand heart (`brand/gradient/0`), for hero art.
    ///
    /// Deliberately not palette slot 0, even though the Figma comp inherits it there: a
    /// slot identifies a participant and moves when the palette is re-derived, which is
    /// exactly what a logo must not do.
    static let brandHeart = Color(hex: "FF6B9D")

    /// The `on` colours of the tint pairs, which is what a value coloured against a dark
    /// background needs. Measured for AA in the iPhone token backport.
    static let starGold = Color(hex: "FEF3C7")
    static let syncGreen = Color(hex: "DCFCE7")
    static let clusterPurple = Color(hex: "F3E8FF")
}
