import SwiftUI

/// In a room, sharing, but alone — the user's own heart and nothing to compare it to.
///
/// Distinct from Idle on purpose: the workout *is* running and the BPM *is* leaving the
/// watch, and collapsing the two states would make a working session look broken.
struct WatchWaitingView: View {

    let heartRate: Double
    /// Same affordance as the room screen's: being alone in a room must not be a state
    /// you can only leave from the phone.
    let onStop: () -> Void

    private var bpm: Int { Int(heartRate.rounded()) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                WatchHeartIcon(color: WatchTheme.brandHeart, size: 18, showGlow: heartRate > 0)
                    .symbolEffect(.pulse, isActive: heartRate > 0)

                Text(bpm > 0 ? "\(bpm)" : "--")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.textPrimary)
                    .contentTransition(.numericText())
            }

            Text("Waiting for hearts…")
                .font(.caption2)
                .foregroundStyle(WatchTheme.textSecondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Waiting for other hearts")
                .accessibilityValue(bpm > 0 ? "Your heart rate, \(bpm) beats per minute" : "No heart rate yet")

            Button(action: onStop) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel("Leave room")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchTheme.background)
    }
}

#Preview("With a reading") {
    WatchWaitingView(heartRate: 72, onStop: {})
}

#Preview("Before the first beat") {
    WatchWaitingView(heartRate: 0, onStop: {})
}
