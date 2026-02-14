import SwiftUI

struct WatchHeartIcon: View {
    let color: Color
    var size: CGFloat
    var showGlow: Bool

    init(color: Color, size: CGFloat = 14, showGlow: Bool = false) {
        self.color = color
        self.size = size
        self.showGlow = showGlow
    }

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(color.gradient)
            .shadow(color: showGlow ? color.opacity(0.5) : .clear, radius: 4)
    }
}
