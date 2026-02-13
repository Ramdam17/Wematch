import SwiftUI

enum WematchTheme {

    // MARK: - Background Gradient

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "FDF2F8"),
            Color(hex: "F3E8FF"),
            Color(hex: "EDE9FE")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Primary Gradient (Pink → Purple → Cyan)

    static let primaryGradient = LinearGradient(
        colors: [
            Color(hex: "FF6B9D"),
            Color(hex: "C084FC"),
            Color(hex: "67E8F9")
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Glass Effect

    static let glassBorderColor = Color.white.opacity(0.6)

    // MARK: - Text Colors

    static let textPrimary = Color(hex: "1F1F1F")
    static let textSecondary = Color(hex: "6B7280")
    static let textOnColor = Color.white

    // MARK: - Heart Palette (20+ distinct colors)

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

    // MARK: - Spacing

    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24

    // MARK: - Corner Radius

    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24
}
