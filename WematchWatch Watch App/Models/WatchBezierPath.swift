import SwiftUI

// MARK: - Bezier Path

struct WatchBezierPath: Sendable {
    let from: CGPoint
    let to: CGPoint
    let control1: CGPoint
    let control2: CGPoint

    func point(at t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt

        let x = mt3 * from.x + 3 * mt2 * t * control1.x + 3 * mt * t2 * control2.x + t3 * to.x
        let y = mt3 * from.y + 3 * mt2 * t * control1.y + 3 * mt * t2 * control2.y + t3 * to.y
        return CGPoint(x: x, y: y)
    }

    static func curved(from: CGPoint, to: CGPoint, curvature: CGFloat = 0.3) -> WatchBezierPath {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = hypot(dx, dy)

        guard distance > 0.1 else {
            return WatchBezierPath(from: from, to: to, control1: from, control2: to)
        }

        let perpX = -dy / distance
        let perpY = dx / distance
        let offset = distance * curvature

        let c1 = CGPoint(
            x: from.x + dx * 0.33 + perpX * offset,
            y: from.y + dy * 0.33 + perpY * offset
        )
        let c2 = CGPoint(
            x: from.x + dx * 0.66 - perpX * offset * 0.5,
            y: from.y + dy * 0.66 - perpY * offset * 0.5
        )

        return WatchBezierPath(from: from, to: to, control1: c1, control2: c2)
    }
}

// MARK: - Bezier Position Modifier

struct WatchBezierPositionModifier: ViewModifier, Animatable {
    var path: WatchBezierPath
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let pos = path.point(at: progress)
        content.position(pos)
    }
}

extension View {
    func watchBezierPosition(path: WatchBezierPath, progress: CGFloat) -> some View {
        modifier(WatchBezierPositionModifier(path: path, progress: progress))
    }
}
