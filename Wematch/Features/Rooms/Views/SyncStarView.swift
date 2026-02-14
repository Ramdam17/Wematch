import SwiftUI

/// A sparkle/glow star that appears when hearts sync.
/// Rainbow unicorn aesthetic with pulsing animation.
struct SyncStarView: View {
    let star: SyncStar

    @State private var isPulsing = false

    /// Cycle through theme colors based on star ID hash.
    private var starColor: Color {
        let index = abs(star.id.hashValue) % WematchTheme.heartColors.count
        return WematchTheme.heartColors[index]
    }

    var body: some View {
        ZStack {
            // Outer glow
            Image(systemName: "sparkle")
                .font(.system(size: 20))
                .foregroundStyle(starColor.opacity(0.3))
                .blur(radius: 6)
                .scaleEffect(isPulsing ? 1.3 : 1.0)

            // Inner sparkle
            Image(systemName: "sparkle")
                .font(.system(size: 14))
                .foregroundStyle(
                    LinearGradient(
                        colors: [starColor, .white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isPulsing ? 1.1 : 0.9)
        }
        .opacity(star.opacity)
        .animation(
            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
            value: isPulsing
        )
        .onAppear { isPulsing = true }
    }
}
