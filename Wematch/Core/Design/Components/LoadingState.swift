import SwiftUI

/// The app's one loading surface: a pulsing heart and a quiet line of text.
///
/// Exists so waiting reads as the app breathing rather than as a system spinner. Use it
/// wherever a whole screen or section is waiting; a bare `ProgressView` is still right
/// inside a button, where a beating heart would be absurd.
struct LoadingState: View {
    let message: String

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(message: String = "Finding heartbeats…") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: WematchTheme.paddingMedium) {
            HeartIcon(
                color: WematchTheme.brandHeart,
                size: 28,
                showGlow: true,
                showOutline: true
            )
            .scaleEffect(isPulsing ? 1.12 : 0.92)
            .animation(pulse, value: isPulsing)
            .onAppear { isPulsing = true }

            Text(message)
                .font(WematchTypography.callout)
                .foregroundStyle(WematchTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        // A perpetual animation is exactly what Reduce Motion is for (audit G3): the heart
        // simply rests at full size instead.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var pulse: Animation? {
        reduceMotion
            ? nil
            : .spring(duration: 0.9, bounce: 0.3).repeatForever(autoreverses: true)
    }
}

#Preview("Loading") {
    ZStack {
        WematchTheme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 48) {
            LoadingState()
            LoadingState(message: "Joining the room…")
        }
    }
}
