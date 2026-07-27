import SwiftUI

struct HeartIcon: View {
    let color: Color
    var size: CGFloat
    var showGlow: Bool
    /// Draws the `plot/marker-outline` token behind the heart.
    ///
    /// The token is transparent in Dark Cosmic, so this costs nothing there. In Pastel
    /// Light it gives plot markers a sticker edge, which is what keeps twenty hues
    /// separable from each other and from a pale background. Approximated by the same
    /// symbol scaled up behind, since SF Symbols carry no stroke of their own.
    var showOutline: Bool

    init(color: Color, size: CGFloat = 32, showGlow: Bool = false, showOutline: Bool = false) {
        self.color = color
        self.size = size
        self.showGlow = showGlow
        self.showOutline = showOutline
    }

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(color.gradient)
            .shadow(color: showGlow ? color.opacity(0.6) : .clear, radius: 8)
            .overlay(
                Image(systemName: "heart.fill")
                    .font(.system(size: size))
                    .foregroundStyle(.white.opacity(0.3))
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background {
                if showOutline {
                    Image(systemName: "heart.fill")
                        .font(.system(size: size * 1.16))
                        .foregroundStyle(WematchTheme.plotMarkerOutline)
                }
            }
    }
}

#Preview {
    ZStack {
        WematchTheme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                HeartIcon(color: WematchTheme.heartColors[0], size: 40)
                HeartIcon(color: WematchTheme.heartColors[1], size: 40, showGlow: true)
                HeartIcon(color: WematchTheme.heartColors[2], size: 40, showGlow: true)
            }
            HStack(spacing: 20) {
                ForEach([0, 7, 12], id: \.self) { slot in
                    HeartIcon(
                        color: WematchTheme.heartColors[slot],
                        size: 28,
                        showOutline: true
                    )
                }
            }
        }
    }
}
