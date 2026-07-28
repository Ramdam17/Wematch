import SwiftUI

/// No room, no workout — the honest resting state.
///
/// Replaces the old placeholder's "Waiting for room…", which claimed the Watch was doing
/// something it was not. Nothing here is animated: an idle screen that pulses forever is
/// a battery cost paid for a lie.
struct WatchIdleView: View {

    var body: some View {
        VStack(spacing: 10) {
            WatchHeartIcon(color: WatchTheme.brandHeart, size: 34)
                .opacity(0.55)
                .accessibilityHidden(true)

            Text("No active room")
                .font(.headline)
                .foregroundStyle(WatchTheme.textPrimary)

            Text("Start a room on your iPhone — your heart will wake up here.")
                .font(.caption2)
                .foregroundStyle(WatchTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchTheme.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No active room")
        .accessibilityHint("Start a room on your iPhone to begin sharing your heart rate")
    }
}

#Preview {
    WatchIdleView()
}
