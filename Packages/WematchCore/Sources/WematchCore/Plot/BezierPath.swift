import SwiftUI

// The Watch carried a `Watch`-prefixed copy of everything below, character for character
// (plan 1.11). Two implementations of the same curve is two ways for the same room to be
// drawn differently on the two screens looking at it.

// MARK: - Bezier Path

public struct BezierPath: Sendable {
    public let from: CGPoint
    public let to: CGPoint
    public let control1: CGPoint
    public let control2: CGPoint

    public init(from: CGPoint, to: CGPoint, control1: CGPoint, control2: CGPoint) {
        self.from = from
        self.to = to
        self.control1 = control1
        self.control2 = control2
    }

    /// Evaluate position along the cubic Bezier curve at parameter t (0...1).
    public func point(at t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt

        let x = mt3 * from.x + 3 * mt2 * t * control1.x + 3 * mt * t2 * control2.x + t3 * to.x
        let y = mt3 * from.y + 3 * mt2 * t * control1.y + 3 * mt * t2 * control2.y + t3 * to.y
        return CGPoint(x: x, y: y)
    }

    /// Generate a Bezier path with control points offset perpendicular to the movement vector.
    /// `curvature` controls how far control points deviate (0 = straight line, 1 = large arc).
    public static func curved(from: CGPoint, to: CGPoint, curvature: CGFloat = 0.3) -> BezierPath {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = hypot(dx, dy)

        guard distance > 0.1 else {
            // Points are essentially the same — straight line
            return BezierPath(from: from, to: to, control1: from, control2: to)
        }

        // Perpendicular offset direction
        let perpX = -dy / distance
        let perpY = dx / distance
        let offset = distance * curvature

        // Control points at 1/3 and 2/3 along the path, offset perpendicularly
        let c1 = CGPoint(
            x: from.x + dx * 0.33 + perpX * offset,
            y: from.y + dy * 0.33 + perpY * offset
        )
        let c2 = CGPoint(
            x: from.x + dx * 0.66 - perpX * offset * 0.5,
            y: from.y + dy * 0.66 - perpY * offset * 0.5
        )

        return BezierPath(from: from, to: to, control1: c1, control2: c2)
    }
}

// MARK: - Bezier Position Modifier

/// `@MainActor` where the rest of the package is `nonisolated`: `ViewModifier.body` is
/// main-actor isolated. `Animatable` is not, and SwiftUI drives `animatableData` from the
/// render loop, so the conformance is `@preconcurrency` — the same thing the apps got for
/// free from their project-wide main-actor default, said out loud here.
@MainActor
public struct BezierPositionModifier: ViewModifier, @preconcurrency Animatable {
    var path: BezierPath
    var progress: CGFloat

    init(path: BezierPath, progress: CGFloat) {
        self.path = path
        self.progress = progress
    }

    public var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    public func body(content: Content) -> some View {
        let pos = path.point(at: progress)
        content.position(pos)
    }
}

extension View {
    @MainActor
    public func bezierPosition(path: BezierPath, progress: CGFloat) -> some View {
        modifier(BezierPositionModifier(path: path, progress: progress))
    }
}
