import SwiftUI

/// How loudly a toast speaks. Each level is a tint pair, so the text is legible on the
/// fill in both colour modes — the badge lesson from G2 applies here too.
enum ToastSeverity {
    case error
    case warning
    case info

    var tint: TintPair {
        switch self {
        case .error: WematchTheme.tintDanger
        case .warning: WematchTheme.tintPending
        case .info: WematchTheme.tintInfo
        }
    }

    var symbol: String {
        switch self {
        case .error: "exclamationmark.triangle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }

    /// VoiceOver has no colour, so the severity has to be spoken.
    var accessibilityPrefix: String {
        switch self {
        case .error: "Error"
        case .warning: "Warning"
        case .info: "Information"
        }
    }
}

/// The visible half of "no silent failures": a transient pill for errors the user should
/// see but need not act on.
///
/// Deliberately not an alert. An alert is modal and demands a tap, which is wrong for a
/// failure that may repeat every second — a dropped heart-rate write, say. Anything the
/// user must decide about belongs in an alert instead.
struct ErrorToast: View {
    let message: String
    var severity: ToastSeverity = .error

    var body: some View {
        HStack(spacing: WematchTheme.paddingSmall) {
            Image(systemName: severity.symbol)
                .font(WematchTypography.calloutEmphasized)

            Text(message)
                .font(WematchTypography.calloutEmphasized)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(severity.tint.on)
        .padding(.horizontal, WematchTheme.paddingMedium)
        .padding(.vertical, WematchTheme.paddingSmall)
        .background(severity.tint.fill, in: Capsule())
        .wematchGlowSoft()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(severity.accessibilityPrefix). \(message)")
    }
}

#Preview("Severities") {
    ZStack {
        WematchTheme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 12) {
            ErrorToast(message: "Couldn't reach the room.", severity: .error)
            ErrorToast(message: "Heart rate paused — check your Watch.", severity: .warning)
            ErrorToast(message: "You left the room.", severity: .info)
        }
        .padding()
    }
}
