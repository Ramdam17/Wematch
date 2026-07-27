import SwiftUI

/// Type ramp mirroring the Figma text styles (`Display/*`, `Body/*`, `HUD/*`).
///
/// Everything except the HUD scale is relative, so it tracks Dynamic Type.
enum WematchTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title, design: .rounded, weight: .bold)
    static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
    static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let callout = Font.system(.callout, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let caption2 = Font.system(.caption2, design: .default, weight: .regular)

    // MARK: - Emphasized

    static let bodyEmphasized = Font.system(.body, design: .default, weight: .semibold)
    static let calloutEmphasized = Font.system(.callout, design: .default, weight: .semibold)
    static let captionEmphasized = Font.system(.caption, design: .default, weight: .semibold)

    // MARK: - HUD

    // The HUD sizes are fixed on purpose: these are data-visualization readouts sitting
    // in a fixed-height bar over the plot, not chrome. They stay legible through
    // explicit accessibility elements on the HUD instead of through Dynamic Type.
    // Digits are monospaced so a changing BPM does not make the number jitter.

    static let hudNumberLarge = Font.system(size: 24, weight: .bold, design: .rounded)
        .monospacedDigit()
    static let hudNumberSmall = Font.system(size: 13, weight: .semibold, design: .rounded)
        .monospacedDigit()
}
