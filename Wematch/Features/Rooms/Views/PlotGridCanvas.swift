import SwiftUI

struct PlotGridCanvas: View {
    let insets: EdgeInsets
    @Environment(\.colorScheme) private var colorScheme

    private let bpmSteps: [Int] = stride(from: 40, through: 200, by: 20).map { $0 }

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
            drawAxisLabels(context: context, plotRect: plotRect, size: size)
        }
    }

    // MARK: - Grid Lines

    private func drawGridLines(context: GraphicsContext, plotRect: CGRect) {
        let lineColor = colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)

        for bpm in bpmSteps {
            let norm = PlotCoordinates.normalize(Double(bpm))

            // Vertical line (X axis = previousHR)
            let x = plotRect.minX + norm * plotRect.width
            var vPath = Path()
            vPath.move(to: CGPoint(x: x, y: plotRect.minY))
            vPath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(vPath, with: .color(lineColor), lineWidth: 0.5)

            // Horizontal line (Y axis = currentHR, flipped)
            let y = plotRect.maxY - norm * plotRect.height
            var hPath = Path()
            hPath.move(to: CGPoint(x: plotRect.minX, y: y))
            hPath.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            context.stroke(hPath, with: .color(lineColor), lineWidth: 0.5)
        }
    }

    // MARK: - Diagonal X = Y

    private func drawDiagonal(context: GraphicsContext, plotRect: CGRect) {
        let diagColor = colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.12)

        var diagPath = Path()
        diagPath.move(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        diagPath.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.minY))

        context.stroke(
            diagPath,
            with: .color(diagColor),
            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
        )
    }

    // MARK: - Axis Labels

    private func drawAxisLabels(context: GraphicsContext, plotRect: CGRect, size: CGSize) {
        let labelColor = colorScheme == .dark
            ? Color.white.opacity(0.35)
            : Color.black.opacity(0.35)

        let font = Font.system(size: 9, weight: .medium, design: .rounded)

        // Show labels at every other step to avoid clutter: 40, 80, 120, 160, 200
        let labelSteps = bpmSteps.filter { ($0 - 40) % 40 == 0 }

        for bpm in labelSteps {
            let norm = PlotCoordinates.normalize(Double(bpm))
            let text = Text("\(bpm)").font(font).foregroundStyle(labelColor)

            // X axis label (below plot)
            let x = plotRect.minX + norm * plotRect.width
            context.draw(
                context.resolve(text),
                at: CGPoint(x: x, y: plotRect.maxY + 12),
                anchor: .top
            )

            // Y axis label (left of plot)
            let y = plotRect.maxY - norm * plotRect.height
            context.draw(
                context.resolve(text),
                at: CGPoint(x: plotRect.minX - 6, y: y),
                anchor: .trailing
            )
        }
    }
}
