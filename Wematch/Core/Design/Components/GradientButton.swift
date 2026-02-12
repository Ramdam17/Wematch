import SwiftUI

struct GradientButton: View {
    let title: String
    let action: () -> Void
    var isFullWidth: Bool

    init(_ title: String, isFullWidth: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isFullWidth = isFullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WematchTypography.headline)
                .foregroundStyle(WematchTheme.textOnColor)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.vertical, 14)
                .padding(.horizontal, WematchTheme.paddingLarge)
                .background(WematchTheme.primaryGradient)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "F3E8FF").ignoresSafeArea()
        VStack(spacing: 20) {
            GradientButton("Join Room") {}
            GradientButton("Create", isFullWidth: false) {}
        }
        .padding()
    }
}
