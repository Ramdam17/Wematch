import SwiftUI
import UIKit

/// A fill + foreground colour pair that meets WCAG AA in both colour modes.
///
/// Introduced to close audit finding G2: `StatusBadge` drew white text on pastel
/// fills at roughly 1.5:1, against the 4.5:1 requirement. Each pair is the same two
/// hues swapped between modes, so both directions measure identically — from 6.37:1
/// (pending) to 7.39:1 (accent).
struct TintPair {
    let fill: Color
    let on: Color
}

/// Design tokens, backported from the Figma library (file `b3bezjB9kQ1CcRfghj4Saw`).
///
/// Figma is the source of truth. Its two variable modes map onto the system interface
/// style here: `Pastel Light` → `.light`, `Dark Cosmic` → `.dark`. Tokens resolve
/// themselves per mode, so views never branch on `colorScheme`.
enum WematchTheme {

    // MARK: - Adaptive Color Helpers

    private static func adaptive(light lightHex: String, dark darkHex: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex))
        })
    }

    /// Neutral overlay ink: black in light mode, white in dark mode, each at its own alpha.
    ///
    /// The plot chrome is defined this way in Figma (`black/aXX` ↔ `white/aXX` primitives)
    /// so it stays legible over any background without introducing a hue of its own.
    private static func adaptiveInk(lightAlpha: Double, darkAlpha: Double) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(darkAlpha)
                : UIColor.black.withAlphaComponent(lightAlpha)
        })
    }

    // MARK: - Background

    /// Gradient stops per mode (`bg/0`…`bg/2`), kept as hex so the accessibility tests can
    /// measure against the same values the gradient actually draws.
    static let backgroundHexesLight = ["FDF2F8", "F3E8FF", "EDE9FE"]
    static let backgroundHexesDark = ["1A0B20", "16102C", "12102A"]

    static let backgroundColors: [Color] = zip(backgroundHexesLight, backgroundHexesDark)
        .map { adaptive(light: $0, dark: $1) }

    static let backgroundGradient = LinearGradient(
        colors: backgroundColors,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// `bg/1` on its own, as an opaque surface.
    ///
    /// The gradient's middle stop doubles as the recessed track of controls that sit on
    /// glass — Figma's `.segmented` pill. Named separately because reaching for
    /// `backgroundColors[1]` at a call site says nothing about why that stop.
    static let surfaceInset = backgroundColors[1]

    // MARK: - Action Gradient

    /// Gradient for interactive surfaces and the HUD's hero number
    /// (`action/primary/start` → `action/primary/end`).
    ///
    /// Replaces the decorative brand gradient that used to back every button: white
    /// labels over its pale cyan stop measured 1.45:1. These two stops carry white at
    /// 4.60:1 and 5.70:1, and are what the Figma screens use for the same elements.
    static let actionGradient = LinearGradient(
        colors: [
            Color(hex: "DB2777"),
            Color(hex: "7C3AED")
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Glass Effect

    static let glassBorderColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.15)
            : UIColor.white.withAlphaComponent(0.6)
    })

    // MARK: - Text Colors

    static let textPrimary = adaptive(light: "1F1F1F", dark: "F5F5F5")
    /// `text/secondary` — the light value is `gray/600`, not the `gray/500` the code
    /// carried before (4.43:1 on `bg/0`, just under AA; this one measures 6.92:1).
    static let textSecondary = adaptive(light: "4B5563", dark: "9CA3AF")
    static let textOnColor = Color.white

    // MARK: - Tint Pairs

    static let tintPending = TintPair(
        fill: adaptive(light: "FEF3C7", dark: "92400E"),
        on: adaptive(light: "92400E", dark: "FEF3C7")
    )

    static let tintInfo = TintPair(
        fill: adaptive(light: "CFFAFE", dark: "155E75"),
        on: adaptive(light: "155E75", dark: "CFFAFE")
    )

    /// The one tint whose light fill is a step darker than the others (`purple/200`,
    /// not `purple/50`). The other four fills separate from the lavender background by
    /// hue alone — none of them has meaningful luminance separation either. A purple
    /// tint on a purple background cannot, so it takes the luminance step instead;
    /// text still measures 6.41:1.
    static let tintAccent = TintPair(
        fill: adaptive(light: "E9D5FF", dark: "6B21A8"),
        on: adaptive(light: "6B21A8", dark: "F3E8FF")
    )

    static let tintSuccess = TintPair(
        fill: adaptive(light: "DCFCE7", dark: "166534"),
        on: adaptive(light: "166534", dark: "DCFCE7")
    )

    static let tintDanger = TintPair(
        fill: adaptive(light: "FEE2E2", dark: "991B1B"),
        on: adaptive(light: "991B1B", dark: "FEE2E2")
    )

    // MARK: - Heart Palette (20 slots, bimodal)

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
    static let heartColorHexes: [String] = [
        "D3698D", "FA4249", "EFBBA9",
        "FAAA42", "D5C66D", "DCFA42",
        "CFF8A0", "6EFA42", "79D87F",
        "B0E8C4", "42FABC", "5EF7F2",
        "42CAFA", "4A94F2", "425BFA",
        "B9B0E8", "9D6DD5", "E497FC",
        "FA42EF", "E8B0D4",
    ]

    static let heartColors: [Color] = heartColorHexes.map { Color(hex: $0) }

    /// The brand heart (`brand/gradient/0`), for hero art and empty states.
    ///
    /// Deliberately not a palette slot. Slots identify participants and are chosen for
    /// mutual separability, so they move when the palette is re-derived — which is exactly
    /// what a logo must not do. Anything representing the app rather than a person uses
    /// this.
    static let brandHeart = Color(hex: "FF6B9D")

    static func heartColor(for slot: HeartPaletteSlot) -> Color {
        heartColors[slot.index]
    }

    // MARK: - Plot Chrome

    static let plotGridline = adaptiveInk(lightAlpha: 0.08, darkAlpha: 0.08)
    static let plotDiagonal = adaptiveInk(lightAlpha: 0.12, darkAlpha: 0.15)
    static let plotLabel = adaptiveInk(lightAlpha: 0.35, darkAlpha: 0.35)

    /// Load-bearing sticker outline: in light mode this boundary, not the pastel fill, is
    /// what satisfies the 3:1 requirement for a graphical object (WCAG SC 1.4.11).
    ///
    /// 70% is a measured threshold, not a taste. Composited over the backgrounds it
    /// reaches 7.87:1, and it is the lowest strength at which every one of the twenty
    /// fills keeps at least 1.75:1 against it — below that the edge starts dissolving into
    /// the lighter hearts, and at the 35% it began life as, ten of twenty lost their
    /// boundary while the outline itself only managed 2.42:1.
    ///
    /// Transparent in Dark Cosmic, where the fills clear 3:1 on their own (3.29:1).
    static let plotMarkerOutline = adaptiveInk(
        lightAlpha: plotMarkerOutlineLightAlpha,
        darkAlpha: 0
    )

    /// Exposed because the whole accessibility argument for keeping pastel fills in light
    /// mode rests on this number. `HeartPaletteSeparabilityTests` measures it.
    static let plotMarkerOutlineLightAlpha: Double = 0.70

    // MARK: - Spacing

    static let paddingXSmall: CGFloat = 4
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let paddingXLarge: CGFloat = 32

    // MARK: - Corner Radius

    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24
}
