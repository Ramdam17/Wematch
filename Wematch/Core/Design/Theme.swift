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

    static let heartColors: [Color] = [
        Color(hex: "FF6B9D"), Color(hex: "C084FC"), Color(hex: "67E8F9"),
        Color(hex: "F472B6"), Color(hex: "A78BFA"), Color(hex: "34D399"),
        Color(hex: "FBBF24"), Color(hex: "FB923C"), Color(hex: "F87171"),
        Color(hex: "818CF8"), Color(hex: "6EE7B7"), Color(hex: "FDE68A"),
        Color(hex: "93C5FD"), Color(hex: "FCA5A5"), Color(hex: "86EFAC"),
        Color(hex: "FDA4AF"), Color(hex: "D8B4FE"), Color(hex: "5EEAD4"),
        Color(hex: "FCD34D"), Color(hex: "A5B4FC"),
    ]

    // MARK: - Spacing

    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24

    // MARK: - Corner Radius

    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24
}
