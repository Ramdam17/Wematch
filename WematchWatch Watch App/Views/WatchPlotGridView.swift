import SwiftUI

struct WatchPlotGridView: View {
    let insets: EdgeInsets

    /// Fewer steps for small Watch screen: 40, 80, 120, 160, 200
    private let bpmSteps: [Int] = stride(from: 40, through: 200, by: 40).map { $0 }

    var body: some View {
        Canvas { context, size in
            let plotRect = CGRect(
                x: insets.leading,
                y: insets.top,
                width: size.width - insets.leading - insets.trailing,
                height: size.height - insets.top - insets.bottom
            )

            drawGridLines(context: context, plotRect: plotRect)
            drawDiagonal(context: context, plotRect: plotRect)
            drawAxisLabels(context: context, plotRect: plotRect)
        }
    }

    private func drawGridLines(context: GraphicsContext, plotRect: CGRect) {
        let lineColor = Color.white.opacity(0.1)

        for bpm in bpmSteps {
            let norm = WatchPlotCoordinates.normalize(Double(bpm))

            let x = plotRect.minX + norm * plotRect.width
            var vPath = Path()
            vPath.move(to: CGPoint(x: x, y: plotRect.minY))
            vPath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(vPath, with: .color(lineColor), lineWidth: 0.5)

            let y = plotRect.maxY - norm * plotRect.height
            var hPath = Path()
            hPath.move(to: CGPoint(x: plotRect.minX, y: y))
            hPath.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            context.stroke(hPath, with: .color(lineColor), lineWidth: 0.5)
        }
    }

    private func drawDiagonal(context: GraphicsContext, plotRect: CGRect) {
        var diagPath = Path()
        diagPath.move(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        diagPath.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.minY))
        context.stroke(
            diagPath,
            with: .color(Color.white.opacity(0.15)),
            style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])
        )
    }

    private func drawAxisLabels(context: GraphicsContext, plotRect: CGRect) {
        let labelColor = Color.white.opacity(0.4)
        let font = Font.system(size: 7, weight: .medium, design: .rounded)

        // Only show corner labels: 40 and 200
        let labelSteps = [40, 120, 200]

        for bpm in labelSteps {
            let norm = WatchPlotCoordinates.normalize(Double(bpm))
            let text = Text("\(bpm)").font(font).foregroundStyle(labelColor)

            // X axis label (below)
            let x = plotRect.minX + norm * plotRect.width
            context.draw(
                context.resolve(text),
                at: CGPoint(x: x, y: plotRect.maxY + 7),
                anchor: .top
            )

            // Y axis label (left)
            let y = plotRect.maxY - norm * plotRect.height
            context.draw(
                context.resolve(text),
                at: CGPoint(x: plotRect.minX - 3, y: y),
                anchor: .trailing
            )
        }
    }
}
