import SwiftUI

struct AnimatedBackground: View {
    @State private var animate = false

    var body: some View {
        LinearGradient(
            colors: WematchTheme.backgroundColors,
            startPoint: animate ? .topLeading : .topTrailing,
            endPoint: animate ? .bottomTrailing : .bottomLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

#Preview {
    AnimatedBackground()
}
