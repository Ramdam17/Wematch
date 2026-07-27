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

    static let backgroundColors: [Color] = [
        adaptive(light: "FDF2F8", dark: "1A0B20"),
        adaptive(light: "F3E8FF", dark: "16102C"),
        adaptive(light: "EDE9FE", dark: "12102A"),
    ]

    static let backgroundGradient = LinearGradient(
        colors: backgroundColors,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

    // MARK: - Heart Palette (20 distinct colors)

    static let heartColorHexes: [String] = [
        "FF6B9D", "C084FC", "67E8F9",
        "F472B6", "A78BFA", "34D399",
        "FBBF24", "FB923C", "F87171",
        "818CF8", "6EE7B7", "FDE68A",
        "93C5FD", "FCA5A5", "86EFAC",
        "FDA4AF", "D8B4FE", "5EEAD4",
        "FCD34D", "A5B4FC",
    ]

    static let heartColors: [Color] = heartColorHexes.map { Color(hex: $0) }

    // MARK: - Plot Chrome

    static let plotGridline = adaptiveInk(lightAlpha: 0.08, darkAlpha: 0.08)
    static let plotDiagonal = adaptiveInk(lightAlpha: 0.12, darkAlpha: 0.15)
    static let plotLabel = adaptiveInk(lightAlpha: 0.35, darkAlpha: 0.35)

    /// Sticker outline keeping light-mode heart markers separable from a pale
    /// background; transparent in dark mode, where the markers read on their own.
    static let plotMarkerOutline = adaptiveInk(lightAlpha: 0.35, darkAlpha: 0)

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
