import SwiftUI

struct HeartIcon: View {
    let color: Color
    var size: CGFloat
    var showGlow: Bool

    init(color: Color, size: CGFloat = 32, showGlow: Bool = false) {
        self.color = color
        self.size = size
        self.showGlow = showGlow
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
    }
}

#Preview {
    ZStack {
        Color(hex: "F3E8FF").ignoresSafeArea()
        HStack(spacing: 20) {
            HeartIcon(color: Color(hex: "FF6B9D"), size: 40)
            HeartIcon(color: Color(hex: "C084FC"), size: 40, showGlow: true)
            HeartIcon(color: Color(hex: "67E8F9"), size: 40, showGlow: true)
        }
    }
}
