import SwiftUI

extension View {
    /// `Glass/Glow Soft` — the resting elevation for a floating surface.
    ///
    /// Figma expresses shadow blur as a CSS-style diameter (24) where SwiftUI's
    /// `shadow(radius:)` is about half that, hence 12. The tint is deliberate: a coloured
    /// glow rather than a grey drop shadow, which is what keeps the surface feeling lit
    /// from within rather than stamped on top.
    func wematchGlowSoft() -> some View {
        shadow(color: Color(hex: "BF85FC").opacity(0.18), radius: 12, x: 0, y: 4)
    }
}
