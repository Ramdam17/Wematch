import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var padding: CGFloat

    init(
        cornerRadius: CGFloat = WematchTheme.cornerRadiusMedium,
        padding: CGFloat = WematchTheme.paddingMedium,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(WematchTheme.glassBorderColor, lineWidth: 1)
                    )
            )
    }
}

#Preview {
    ZStack {
        Color(hex: "F3E8FF").ignoresSafeArea()
        GlassCard {
            VStack {
                Text("Glass Card")
                    .font(WematchTypography.title2)
                Text("Frosted glass effect")
                    .font(WematchTypography.body)
            }
        }
        .padding()
    }
}
