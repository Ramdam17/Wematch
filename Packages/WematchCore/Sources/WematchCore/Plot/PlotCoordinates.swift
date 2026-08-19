import SwiftUI

/// The plot's coordinate system: X = previous BPM, Y = current BPM, 40–200, Y flipped.
///
/// Shared rather than copied (plan 1.11) because the two screens draw the same room: a
/// range that drifted on one side would put the same heart in two different places.
public enum PlotCoordinates {
    public static let minBPM: Double = 40
    public static let maxBPM: Double = 200
    public static let bpmRange: Double = maxBPM - minBPM

    /// Clamp a BPM value to the plot range.
    public static func clamp(_ bpm: Double) -> Double {
        min(max(bpm, minBPM), maxBPM)
    }

    /// Map a BPM value to a normalized 0...1 position.
    public static func normalize(_ bpm: Double) -> CGFloat {
        CGFloat((clamp(bpm) - minBPM) / bpmRange)
    }

    /// Convert (previousHR, currentHR) to pixel position in a given plot size.
    /// X axis = previousHR (left to right), Y axis = currentHR (bottom to top).
    public static func position(previousHR: Double, currentHR: Double, in size: CGSize, insets: EdgeInsets) -> CGPoint {
        let plotWidth = size.width - insets.leading - insets.trailing
        let plotHeight = size.height - insets.top - insets.bottom

        let x = insets.leading + normalize(previousHR) * plotWidth
        let y = insets.top + (1 - normalize(currentHR)) * plotHeight // Flip Y

        return CGPoint(x: x, y: y)
    }
}
