import SwiftUI

// MARK: - Bezier Path

struct BezierPath: Sendable {
    let from: CGPoint
    let to: CGPoint
    let control1: CGPoint
    let control2: CGPoint

    /// Evaluate position along the cubic Bezier curve at parameter t (0...1).
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

    /// Generate a Bezier path with control points offset perpendicular to the movement vector.
    /// `curvature` controls how far control points deviate (0 = straight line, 1 = large arc).
    static func curved(from: CGPoint, to: CGPoint, curvature: CGFloat = 0.3) -> BezierPath {
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

struct BezierPositionModifier: ViewModifier, Animatable {
    var path: BezierPath
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
    func bezierPosition(path: BezierPath, progress: CGFloat) -> some View {
        modifier(BezierPositionModifier(path: path, progress: progress))
    }
}

// MARK: - Plot Coordinate Helpers

enum PlotCoordinates {
    static let minBPM: Double = 40
    static let maxBPM: Double = 200
    static let bpmRange: Double = maxBPM - minBPM

    /// Clamp a BPM value to the plot range.
    static func clamp(_ bpm: Double) -> Double {
        min(max(bpm, minBPM), maxBPM)
    }

    /// Map a BPM value to a normalized 0...1 position.
    static func normalize(_ bpm: Double) -> CGFloat {
        CGFloat((clamp(bpm) - minBPM) / bpmRange)
    }

    /// Convert (previousHR, currentHR) to pixel position in a given plot size.
    /// X axis = previousHR (left to right), Y axis = currentHR (bottom to top).
    static func position(previousHR: Double, currentHR: Double, in size: CGSize, insets: EdgeInsets) -> CGPoint {
        let plotWidth = size.width - insets.leading - insets.trailing
        let plotHeight = size.height - insets.top - insets.bottom

        let x = insets.leading + normalize(previousHR) * plotWidth
        let y = insets.top + (1 - normalize(currentHR)) * plotHeight // Flip Y

        return CGPoint(x: x, y: y)
    }
}
