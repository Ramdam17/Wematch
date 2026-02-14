import SwiftUI

enum WatchPlotCoordinates {
    static let minBPM: Double = 40
    static let maxBPM: Double = 200
    static let bpmRange: Double = maxBPM - minBPM

    static func clamp(_ bpm: Double) -> Double {
        min(max(bpm, minBPM), maxBPM)
    }

    static func normalize(_ bpm: Double) -> CGFloat {
        CGFloat((clamp(bpm) - minBPM) / bpmRange)
    }

    /// Convert (previousHR, currentHR) to pixel position.
    /// X = previousHR, Y = currentHR (Y flipped: bottom=40, top=200).
    static func position(previousHR: Double, currentHR: Double, in size: CGSize, insets: EdgeInsets) -> CGPoint {
        let plotWidth = size.width - insets.leading - insets.trailing
        let plotHeight = size.height - insets.top - insets.bottom

        let x = insets.leading + normalize(previousHR) * plotWidth
        let y = insets.top + (1 - normalize(currentHR)) * plotHeight

        return CGPoint(x: x, y: y)
    }
}
